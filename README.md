# Project README

The intent of this project is to give the everyday user who does not have unlimited GPU processing power a good local AI setup with as few steps as possible.
Keep in mind these models do not have as many parameters as the big cloud models, be detailed and specific in your prompts.
It is implied that general purpose agents should not be used for coding
Smaller models may struggle with accuracy and hallucinations

Current Models
qwen2.5-coder-7b-instruct-q5_k_m
qwen2.5-coder-14b-instruct-q5_k_m
Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL
Qwythos-9B-v2-Q5_K_M

## Prerequisites

### System Requirements
- 32, 24, 16, 10, 8 GB VRAM GPU depending on what model you want to run.
- Nvidia GPU
- 16 GB DRAM + the amount of DRAM needed for the OS (Windows is usually about 8 GB, which would be 24 GB total).
- 32 (or less depending on the model) GB of Storage

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

For Coding Agents
Click on your profile --> Admin Panel --> Settings --> Models --> Enter into your model ->
Code Interpreter should be used for reading code you provide, not for asking questions about code or for code generation from scratch.
Enable Code Interpreter, Web Search, File Upload, File Context, Terminal, Builtin Tools, disable everything else
Under Builtin Tools enable Time & Calculation, Memory, Chat History, Notes, Knowledge Base, Channels, Web Search, Code Interpreter, Task Management, Automations, Calendar, disable everything else
Expand the Advanced Params, change Function Calling from default/native to legacy
Save

For General Agents
Click on your profile --> Admin Panel --> Settings --> Models --> Enter into your model ->
Enable  Web Search, File Upload, File Context, Terminal, Builtin Tools, disable everything else
Under Builtin Tools enable Time & Calculation, Memory, Chat History, Notes, Knowledge Base, Channels, Web Search, Task Management, Automations, Calendar, disable everything else
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
