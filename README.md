# Student Attendance Tracker — Deployment Agent

## Contents

- `deploy_agent.sh` — menu-driven deploy, run, and archive script.
- `templates/attendance_checker.py` — **must be the original, unmodified course file**.
- `templates/assets.csv` — original 10-student sample roster.
- `templates/config.json` — original configuration template.

> The three source files were not bundled with this scaffold. Download them from the course page and place them in `templates/` without editing them before running the script.

## Requirements

- Bash
- `python3`
- `zip`
- Standard Unix tools: `cp`, `chmod`, `mkdir`, `head`, `sed`, `date`, and `rm`

On macOS, the script uses the macOS-compatible `sed -i ''` form. On Linux, it uses GNU `sed -i`.

## Run the agent

From this repository directory:

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh
```

Select from the menu:

1. **Deploy application** — asks for a project name, creates `attendance_tracker_<name>/`, builds a roster, sets permissions, optionally updates thresholds, and launches the application as a startup verification.
2. **Run existing application** — runs `python3 attendance_checker.py` from the selected project's root.
3. **Archive logs** — copies each existing log to its own timestamped archive directory.
4. **Exit**.

The expected deployed structure is:

```text
attendance_tracker_<name>/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
├── reports/
└── archives/                 # created when logs are archived
    ├── attendance/
    └── absent/
```

The Python application is not modified. Its fixed paths are respected by placing the roster and configuration in `Helpers/` and running Python from the project root.

## Roster choices and session counts

During deployment:

- **Option A** copies the header and the requested number of rows from `templates/assets.csv`. The sample roster records four prior sessions per student, so `Helpers/config.json` is set to `"total_sessions": 5`.
- **Option B** generates a fresh roster from arrays in the shell script. Attendance and absence counts start at zero, so `Helpers/config.json` is set to `"total_sessions": 1`.

The script accepts 1–10 students because the provided sample roster and the built-in sample arrays each contain 10 students.

## Permissions and thresholds

- `attendance_checker.py` is made executable with `chmod +x`.
- `Helpers/config.json` is set to mode `600` (`rw-------`), so only the file owner can read or write grading-sensitive thresholds.
- The threshold prompt accepts whole numbers from 0 through 100. Press Enter to use the defaults: warning `75`, failure `50`.
- If the user chooses to update thresholds, `sed` changes only the matching `"warning": number` and `"failure": number` lines in the deployed JSON, without reordering or reformatting the file.

If permission changes fail, the script reports the error rather than claiming success. Run it from a directory where you have permission to create files.

## Log archival

After a marking session, select **3) Archive logs**. The script checks each file separately:

- `reports/attendance.log` → `archives/attendance/attendance_YYYYMMDD_HHMMSS.log`
- `reports/absent.log` → `archives/absent/absent_YYYYMMDD_HHMMSS.log`

The timestamp is generated when the archive action starts. Each existing log is copied with its own final path printed. If a log does not exist (for example, no absences were logged), the script prints a friendly message and continues. Archiving copies rather than removes the original report logs.

## Signal handling: Ctrl+C and Ctrl+Z during deployment

Signal traps are installed only while Feature 1 is creating/configuring the project. If Ctrl+C (`SIGINT`) or Ctrl+Z (`SIGTSTP`) is pressed during that phase, the handler:

1. Prints an interruption message.
2. Uses `zip` to create `attendance_tracker_<name>_archive.zip` containing the partial project directory, if it exists.
3. Removes the incomplete working directory to avoid workspace clutter.
4. Exits cleanly with status 130.

This trap is intentionally disabled before the attendance application starts; it does not intercept signals during the instructor's marking session.

### How to test the interrupt path

1. Use a disposable project name and start Feature 1.
2. Once the project directory has been created and setup is still in progress, press Ctrl+C or Ctrl+Z.
3. Confirm that `attendance_tracker_<name>_archive.zip` exists beside the script and that the incomplete `attendance_tracker_<name>/` directory has been removed.
4. Inspect the archive with:

   ```bash
   unzip -l attendance_tracker_<name>_archive.zip
   ```

Because deployment steps can run quickly, you may need to test in a disposable copy with a temporary delay added locally, then remove that test-only delay before submitting. Do not leave artificial delays in the submitted script.

## Validation checklist

Before submitting:

- [x] Put all three original, unmodified source files into `templates/`. Verified using `diff -s`; all three files are identical to the instructor's originals.
- [x] Run `bash -n deploy_agent.sh` to check shell syntax.
- [x] Deploy with Option A and verify the header, three requested student rows, and `total_sessions` set to `5`.
- [x] Verify Option B generates fresh roster counts of `0` and sets `total_sessions` to `1`.
- [x] Confirm the Python version is printed and missing `python3`/`zip` produces a clear error.
- [x] Confirm permissions: the deployed Python application is executable and `Helpers/config.json` has mode `600`.
- [x] Test default and custom thresholds; verified that 101 and -1 are rejected, while valid thresholds 75 and 50 are accepted.
- [x] Complete a live attendance-marking session and verify attendance and absence logs are created.
- [x] Archive logs and verify filenames/directories for both attendance and absence logs.
- [x] Test the missing-log case.
- [x] Test both Ctrl+C and Ctrl+Z in disposable deployments and inspect the ZIP archive.
- [x] Commit the work to your GitHub repository, `deploy_agent_Isimbisunny`, with meaningful commit messages.
- [ ] Add your run-through video link below.

## Walk-through Video

 https://drive.google.com/file/d/1IM-TmFjzw0ua4jUSwO-Q5GjSR9GzUwQU/view?usp=sharing