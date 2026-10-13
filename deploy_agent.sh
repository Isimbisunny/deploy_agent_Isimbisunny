#!/usr/bin/env bash
# Student Attendance Tracker deployment, execution, and log archival agent.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
PROJECT_DIR=""
DEPLOYING=0

error() { printf 'ERROR: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        error "Required command '$1' is not installed or is not in PATH."
        return 1
    fi
}

valid_positive_integer() {
    [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

# During deployment, preserve the partial project in a real ZIP, then remove
# the incomplete working directory. Outside deployment, do not intercept signals.
handle_deploy_signal() {
    local signal_name="$1"
    trap '' INT TSTP
    if [[ "$DEPLOYING" -eq 1 ]]; then
        printf '\nDeployment interrupted by %s. Saving the partial project...\n' "$signal_name"
        if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
            local zip_path="${PROJECT_DIR}_archive.zip"
            if (cd -- "$(dirname -- "$PROJECT_DIR")" && zip -qr "$zip_path" "$(basename -- "$PROJECT_DIR")"); then
                printf 'Partial deployment archived at: %s\n' "$zip_path"
            else
                error "Could not create the ZIP archive at $zip_path."
            fi
            if rm -rf -- "$PROJECT_DIR"; then
                printf 'Removed incomplete directory: %s\n' "$PROJECT_DIR"
            else
                error "Could not remove incomplete directory: $PROJECT_DIR"
            fi
        else
            info "No project directory had been created yet; nothing to archive."
        fi
    fi
    exit 130
}

ask_project_name() {
    local name
    while true; do
        read -r -p "Project name (letters, numbers, _ or -; prefix attendance_tracker_ is added): " name
        if [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            PROJECT_DIR="$SCRIPT_DIR/attendance_tracker_${name}"
            return 0
        fi
        error "Use only letters, numbers, underscores, and hyphens."
    done
}

check_templates() {
    local file
    for file in attendance_checker.py assets.csv config.json; do
        if [[ ! -f "$TEMPLATE_DIR/$file" ]]; then
            error "Missing template: $TEMPLATE_DIR/$file"
            error "Place the three unmodified provided source files in templates/ and try again."
            return 1
        fi
    done
}

update_config_value() {
    local key="$1" value="$2" file="$3"
    # macOS and GNU sed use different in-place syntax.
    if [[ "$OSTYPE" == darwin* ]]; then
        sed -i '' -E "s/^([[:space:]]*\"${key}\"[[:space:]]*:[[:space:]]*)[0-9]+([[:space:]]*,?[[:space:]]*)$/\\1${value}\\2/" "$file"
    else
        sed -i -E "s/^([[:space:]]*\"${key}\"[[:space:]]*:[[:space:]]*)[0-9]+([[:space:]]*,?[[:space:]]*)$/\\1${value}\\2/" "$file"
    fi
}

prompt_threshold() {
    local label="$1" default="$2" value
    while true; do
        read -r -p "$label threshold [default $default]: " value
        value="${value:-$default}"
        if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= 100 )); then
            printf '%s' "$value"
            return 0
        fi
        error "Enter a whole number from 0 to 100."
    done
}

deploy_app() {
    require_command python3 || return 1
    require_command zip || return 1
    info "Python environment check:"
    python3 --version || { error "python3 is installed but could not run."; return 1; }
    check_templates || return 1

    ask_project_name
    if [[ -e "$PROJECT_DIR" ]]; then
        local answer
        read -r -p "$PROJECT_DIR already exists. Overwrite it? This deletes its contents [y/N]: " answer
        case "$answer" in
            y|Y|yes|YES)
                if ! rm -rf -- "$PROJECT_DIR"; then
                    error "Cannot remove existing project. Check directory permissions."
                    return 1
                fi
                ;;
            *)
                error "Deployment cancelled; existing directory was not changed."
                return 1
                ;;
        esac
    fi

    DEPLOYING=1
    trap 'handle_deploy_signal SIGINT' INT
    trap 'handle_deploy_signal SIGTSTP' TSTP

    if ! mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports"; then
        error "Could not create project directories. Check parent-directory permissions."
        DEPLOYING=0
        trap - INT TSTP
        return 1
    fi

    if ! cp "$TEMPLATE_DIR/attendance_checker.py" "$PROJECT_DIR/attendance_checker.py" ||
       ! cp "$TEMPLATE_DIR/config.json" "$PROJECT_DIR/Helpers/config.json"; then
        error "Could not copy application/config templates. Check file permissions."
        return 1
    fi

    info "Choose how to create the roster:"
    info "A) Copy rows from templates/assets.csv (each sample row has 4 prior sessions)"
    info "B) Generate a fresh roster (counts start at 0)"
    local roster_choice count
    while true; do
        read -r -p "Choose A or B: " roster_choice
        case "$roster_choice" in
            A|a)
                while true; do
                    read -r -p "How many template students (1-10) should be copied? " count
                    if valid_positive_integer "$count" && (( count <= 10 )); then break; fi
                    error "Enter a whole number from 1 to 10."
                done
                if ! head -n "$((count + 1))" "$TEMPLATE_DIR/assets.csv" > "$PROJECT_DIR/Helpers/assets.csv"; then
                    error "Could not create roster. Check file permissions."
                    return 1
                fi
                update_config_value total_sessions 5 "$PROJECT_DIR/Helpers/config.json" || return 1
                break
                ;;
            B|b)
                while true; do
                    read -r -p "How many students (1-10)? " count
                    if valid_positive_integer "$count" && (( count <= 10 )); then break; fi
                    error "Enter a whole number from 1 to 10."
                done
                local -a names=("Alice Johnson" "Bob Smith" "Chloe Uwimana" "Daniel Niyonzima" "Ella Mukamana" "Frank Habimana" "Grace Ingabire" "Henry Mugisha" "Irene Uwera" "James Karemera")
                local -a emails=("alice@example.com" "bob@example.com" "chloe@example.com" "daniel@example.com" "ella@example.com" "frank@example.com" "grace@example.com" "henry@example.com" "irene@example.com" "james@example.com")
                {
                    printf 'Email,Names,Attendance Count,Absence Count\n'
                    local i
                    for ((i=0; i<count; i++)); do
                        printf '%s,"%s",0,0\n' "${emails[$i]}" "${names[$i]}"
                    done
                } > "$PROJECT_DIR/Helpers/assets.csv" || { error "Could not write fresh roster."; return 1; }
                update_config_value total_sessions 1 "$PROJECT_DIR/Helpers/config.json" || return 1
                break
                ;;
            *)
                error "Choose A or B."
                ;;
        esac
    done

    if ! chmod +x "$PROJECT_DIR/attendance_checker.py"; then
        error "Could not make attendance_checker.py executable. Check permissions."
        return 1
    fi
    if ! chmod 600 "$PROJECT_DIR/Helpers/config.json"; then
        error "Could not restrict config.json permissions. Check permissions."
        return 1
    fi
    printf 'Permissions set: attendance_checker.py executable; Helpers/config.json owner read/write only (600).\n'

    local update
    read -r -p "Update alert thresholds? [y/N]: " update
    case "$update" in
        y|Y|yes|YES)
            local warning failure
            warning="$(prompt_threshold "Warning" 75)" || return 1
            failure="$(prompt_threshold "Failure" 50)" || return 1
            if ! update_config_value warning "$warning" "$PROJECT_DIR/Helpers/config.json" ||
               ! update_config_value failure "$failure" "$PROJECT_DIR/Helpers/config.json"; then
                error "Could not update thresholds in config.json."
                return 1
            fi
            info "Updated warning=$warning and failure=$failure."
            ;;
        *)
            info "Keeping template threshold defaults (warning 75, failure 50)."
            ;;
    esac

    DEPLOYING=0
    trap - INT TSTP
    info "Deployment created at: $PROJECT_DIR"
    info "Starting the application now to verify the deployment. Use the instructor prompts to mark attendance."
    run_app
}

choose_existing_project() {
    local name
    read -r -p "Project name (without attendance_tracker_ prefix): " name
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid project name."
        return 1
    fi
    PROJECT_DIR="$SCRIPT_DIR/attendance_tracker_${name}"
    if [[ ! -d "$PROJECT_DIR" ]]; then
        error "Project directory not found: $PROJECT_DIR"
        return 1
    fi
}

run_app() {
    if [[ ! -f "$PROJECT_DIR/attendance_checker.py" ]]; then
        error "attendance_checker.py not found in $PROJECT_DIR"
        return 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        error "python3 is not installed or is not in PATH."
        return 1
    fi
    (cd -- "$PROJECT_DIR" && python3 attendance_checker.py)
}

archive_logs() {
    local timestamp="$1" log_name="$2" archive_dir="$3"
    local source="$PROJECT_DIR/reports/$log_name"
    if [[ -f "$source" ]]; then
        if ! mkdir -p "$PROJECT_DIR/archives/$archive_dir"; then
            error "Could not create archive directory for $log_name."
            return 1
        fi
        local destination="$PROJECT_DIR/archives/$archive_dir/${archive_dir}_${timestamp}.log"
        if cp -p "$source" "$destination"; then
            printf 'Archived %s -> %s\n' "$log_name" "$destination"
        else
            error "Could not archive $source. Check file permissions."
            return 1
        fi
    else
        printf 'Not archived: %s does not exist (this can be normal if no such events were logged).\n' "$source"
    fi
}

archive_app_logs() {
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    archive_logs "$timestamp" attendance.log attendance || return 1
    archive_logs "$timestamp" absent.log absent || return 1
}

show_menu() {
    printf '\nStudent Attendance Tracker Deployment Agent\n'
    printf '1) Deploy application (creates project and starts it)\n'
    printf '2) Run an existing application\n'
    printf '3) Archive logs from an existing application\n'
    printf '4) Exit\n'
    read -r -p "Choose a feature [1-4]: " choice
    case "$choice" in
        1) deploy_app ;;
        2) choose_existing_project && run_app ;;
        3) choose_existing_project && archive_app_logs ;;
        4) exit 0 ;;
        *) error "Choose 1, 2, 3, or 4."; return 1 ;;
    esac
}

# Validate the essential deployment commands before presenting the menu.
require_command python3 || exit 1
require_command zip || exit 1
while true; do
    show_menu || true
done
