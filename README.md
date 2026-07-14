# Project README

The intent of this project is to give the everyday user who does not have unlimited GPU processing power a good local AI setup with as few steps as possible.

## Prerequisites

### System Requirements
- 32, 24, 16 GB VRAM GPU depending on what model you want to run.
- 16 GB DRAM + the amount of DRAM needed for the OS (Windows is usually about 8 GB, which would be 24 GB total).
- 32 GB of Storage

### Windows
- Install **WSL2 (Windows Subsystem for Linux)**
- Install **Docker Desktop**

### Linux
- Install **Docker Desktop**
- Make sure scripts are executable, for example: chmod +x ./scripts/download-model.sh

---

## Running the Program

Ensure prerequisites are running.

### Windows
1. Open a **WSL2 terminal** or **Git Bash Terminal**
2. Navigate to the project folder

### Linux
1. Open a **terminal**
2. Navigate to the project folder

---

## Start the Application

Run the startup script:

```bash
./startup.sh
```

Select your model.

Wait for the process to complete.

Log into OpenWebUI

Click on your profile --> Admin Panel --> Settings --> Models --> Enter into your model ->
Enable Code Interpreter, Web Search, File Upload, File Context, Terminal, Builtin Tools, disable everything else
Under Builtin Tools enable Time & Calculation, Memory, Chat History, Notes, Knowledge Base, Channels, Web Search, Code Interpreter, Task Management, Automations, Calendar, disable everything else
Expand the Advanced Params, change Function Calling from default/native to legacy
Save

Click on your profile --> Admin Panel --> Settings --> Web Search --> enable web search, set to SearXNG as your engine, Search Result Count 4, Concurrent Requests 2 (top), Concurrent Requests (bottom) 12
Save

The first prompt submitted to the model will be slow.

---

## Save and Exit

To safely stop the program:

```bash
./shutdown.sh
```

---

## Completely Uninstall

To completely remove all components:

You will need to use an ADMINISTRATIVE GIT BASH

After opening the Git Bash, change the directory to this folder (WebSearchAi)

```bash
./uninstall.sh
```
You can then safely delete the project folder.

---

## Using the program

Navigate to

```
http://localhost:3000
```
Create your admin account with your own username, email, and password.
Start asking questions or searching in the text window.

---