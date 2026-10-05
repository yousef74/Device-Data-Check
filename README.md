# Device Data Check

**Device Data Check** is a lightweight Windows diagnostic toolkit designed to make common IT device checks quick and simple.

The toolkit runs several diagnostic scripts automatically from a single launcher, so there is no need to open or run each script manually.

## 📋 How to Use

### 1. Download the Files

Download **all files** from this repository.

Make sure that all files are placed inside the **same folder**.

The folder should look like this:

```text
Device Data Check/
│
├── Run-All.bat
├── Main Script.bat
├── Kaspersky-Check.ps1
└── batteryCheck.ps1
```

### 2. Run the Tool

Once all files are in the same folder:

**Double-click:**

```text
Run-All.bat
```

The launcher will automatically run all diagnostic scripts.

### 3. Follow the Results

The scripts will run one after another and display the collected information directly in the command window.

No additional installation is required.

## ⚙️ Requirements

* Windows 10 or Windows 11
* PowerShell
* All project files must remain in the same folder
* Administrator privileges may be required for some checks

## 🛠️ Included Tools

| File                  | Purpose                                        |
| --------------------- | ---------------------------------------------- |
| `Run-All.bat`         | Runs all diagnostic tools automatically        |
| `Main Script.bat`     | Collects general device and system information |
| `Kaspersky-Check.ps1` | Checks Kaspersky endpoint information          |
| `batteryCheck.ps1`    | Performs battery diagnostics                   |

## 🚀 Quick Start

```text
Download Files
      ↓
Put All Files in One Folder
      ↓
Double-Click Run-All.bat
      ↓
Diagnostics Run Automatically
      ↓
Review the Results
```

## 📌 Important

**Do not separate the files into different folders.**

`Run-All.bat` is designed to find and execute the other scripts from the **same directory**.

For the best results, run `Run-All.bat` with **Administrator privileges**.

## 🎯 Purpose

Device Data Check was created to provide IT support technicians and system administrators with a simple way to perform common Windows device checks without manually running multiple scripts and commands.

---

**Device Data Check**
*Simple. Fast. Practical IT Diagnostics.*
