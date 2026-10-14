# Student Attendance Tracker — Deployment Agent

## About the Project

This project is a Bash script that helps set up and manage a Student Attendance Tracker. Instead of creating the project folders and copying files manually, the script does the setup for you.

It has a menu that lets you deploy a new project, run an existing one, archive attendance logs, or exit. I also added input validation, file permissions, and signal handling to make the process safer and easier to manage.

## Project Files

- `deploy_agent.sh` — the main script for deployment, running the application, and archiving logs.
- `templates/attendance_checker.py` — the original Python attendance application.
- `templates/assets.csv` — the sample student roster.
- `templates/config.json` — the configuration template.

**Important:** The three files in `templates/` must remain identical to the original course files. The deployment script works with them without modifying the original templates.

## Requirements

To run the project, you need:

- Bash
- Python 3
- `zip`
- Standard Unix tools, including `cp`, `chmod`, `mkdir`, `head`, `sed`, `date`, and `rm`

The script supports both macOS and Linux. It uses the appropriate `sed` command for each system.

## How to Run It

Open the terminal in the repository directory and run:

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh
```

You will see a menu with four options:

1. **Deploy application** — creates a new project, prepares the student roster, sets permissions, configures thresholds if needed, and starts the application.
2. **Run existing application** — opens an already deployed project and runs the attendance checker.
3. **Archive logs** — saves copies of existing attendance and absence logs in timestamped folders.
4. **Exit** — closes the script.

## How Deployment Works

When deploying a project, the script asks for a project name and creates a directory called `attendance_tracker_<name>`.

The deployed project has this structure:

```text
attendance_tracker_<name>/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
├── reports/
└── archives/
    ├── attendance/
    └── absent/
```

The `archives/` folders are created when logs are archived.

The Python application is kept unchanged. The script places the roster and configuration in the `Helpers/` directory and runs the application from the project root so that its expected file paths work correctly.

## Choosing a Student Roster

During deployment, you can choose between two roster options.

**Option A — Use the sample roster**

The script copies the header and the number of student records you request from the original `assets.csv` file. The sample records already contain four previous sessions, so the configuration is set to `"total_sessions": 5`.

**Option B — Create a fresh roster**

The script creates a new roster using student data defined in the Bash script. Attendance and absence counts start at zero, and `"total_sessions"` is set to `1`.

You can choose between 1 and 10 students for either option.

## File Permissions and Thresholds

The script sets the permissions needed for the application to run:

- `attendance_checker.py` is made executable using `chmod +x`.
- `Helpers/config.json` is set to permission mode `600`, which allows only the file owner to read and write it.

You can also choose attendance warning and failure thresholds. If you press Enter, the script uses the default warning threshold of `75` and failure threshold of `50`.

Thresholds must be whole numbers between 0 and 100. Invalid values, such as `101` or `-1`, are rejected. When custom thresholds are selected, the script updates the matching values in the deployed configuration file.

If a permission change fails, the script reports the error instead of pretending it worked.

## Running an Existing Project

Choose **Option 2** and enter the name of a project that has already been deployed.

Before running the application, the script checks that `attendance_checker.py` exists and that Python 3 is available. It then changes to the project directory and runs the Python application.

This option is useful when you want to record another attendance session without deploying the project again.

## Archiving Attendance Logs

After a marking session, choose **Option 3** and enter the project name.

The script checks for the two report files and copies each existing file into its own archive folder:

- `reports/attendance.log` is copied to `archives/attendance/attendance_YYYYMMDD_HHMMSS.log`.
- `reports/absent.log` is copied to `archives/absent/absent_YYYYMMDD_HHMMSS.log`.

The timestamp helps distinguish archived files from different runs. If one of the logs does not exist, the script informs you and continues. The original report files are not deleted.

## Handling Ctrl+C and Ctrl+Z

I added signal handling for interruptions during project deployment.

If Ctrl+C (`SIGINT`) or Ctrl+Z (`SIGTSTP`) is pressed while the script is setting up a project, it attempts to:

1. Display an interruption message.
2. Create a ZIP archive of the partial project, if the directory exists.
3. Remove the incomplete project directory.
4. Exit with status `130`.

The signal traps are limited to the deployment setup. They are disabled before the attendance application starts, so they do not interfere with the instructor's live marking session.

### Testing the interruption feature

Use a disposable project name to test this feature. Interrupt the script while deployment is still in progress, then check that the archive exists and the incomplete directory has been removed.

You can inspect the archive with:

```bash
unzip -l attendance_tracker_<name>_archive.zip
```

Since deployment may finish quickly, testing the interruption feature can require careful timing. Any temporary delay used for testing should be removed before submission.

## Testing and Validation

I tested the main features of the script, including:

- Checking shell syntax with `bash -n deploy_agent.sh`.
- Deploying a project with Option A and checking the roster and session count.
- Creating a fresh roster with Option B.
- Checking the Python version and handling missing dependencies.
- Verifying the executable permission on the Python application and permission mode `600` on the configuration file.
- Testing default and custom thresholds, including invalid values.
- Running a live attendance-marking session and checking the generated logs.
- Archiving attendance and absence logs and testing the missing-log case.
- Testing both Ctrl+C and Ctrl+Z during deployment and checking the resulting ZIP archives.

The original course files were also checked against the instructor's versions to confirm that they had not been modified.

## Walk-through Video

I recorded a demonstration showing how the deployment agent works, including the main features and testing process.

## Watch the project demonstration on Google Drive

https://drive.google.com/file/d/1IM-TmFjzw0ua4jUSwO-Q5GjSR9GzUwQU/view?usp=sharing 