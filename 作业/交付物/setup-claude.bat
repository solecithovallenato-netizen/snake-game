@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ==============================================
echo   机房一键部署 — Claude Code + 项目
echo   无需管理员权限，全自动
echo ==============================================
echo.

set "WORK_DIR=%USERPROFILE%\claude-portable"
set "NODE_DIR=%WORK_DIR%\node"
set "PROJECT_DIR=%WORK_DIR%\snake-game"

:: 1. Download portable Node.js (no admin needed)
echo [1/4] 下载 Node.js 便携版...
if not exist "%NODE_DIR%\node.exe" (
    mkdir "%NODE_DIR%" 2>nul

    :: Node.js v18 LTS win-x64 zip (portable)
    set "NODE_URL=https://nodejs.org/dist/v18.20.4/node-v18.20.4-win-x64.zip"
    set "NODE_ZIP=%TEMP%\node-portable.zip"

    echo   正在下载 (约 28MB) ...
    powershell -Command "Invoke-WebRequest -Uri '!NODE_URL!' -OutFile '!NODE_ZIP!'" 2>nul

    if not exist "!NODE_ZIP!" (
        echo   下载失败！请手动下载:
        echo   https://nodejs.org/dist/v18.20.4/node-v18.20.4-win-x64.zip
        echo   解压到: %NODE_DIR%
        pause
        exit /b 1
    )

    echo   解压中...
    powershell -Command "Expand-Archive -Path '!NODE_ZIP!' -DestinationPath '%TEMP%\node-extract' -Force" 2>nul
    xcopy /E /Y "%TEMP%\node-extract\node-v18.20.4-win-x64\*" "%NODE_DIR%\" >nul

    echo   Node.js 便携版安装完成
) else (
    echo   Node.js 已存在，跳过
)

:: Add to PATH for this session
set "PATH=%NODE_DIR%;%PATH%"
echo   Node.js:
node --version

:: 2. Install Claude Code (user directory, no admin)
echo.
echo [2/4] 安装 Claude Code...
call npm install -g @anthropic-ai/claude-code 2>&1
if %errorlevel% neq 0 (
    echo   网络不通，换源重试...
    call npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com
)
echo   Claude Code 安装完成

:: 3. Clone project
echo.
echo [3/4] 克隆项目...
if exist "%PROJECT_DIR%" (
    echo   项目已存在，更新中...
    cd /d "%PROJECT_DIR%"
    git pull
) else (
    mkdir "%PROJECT_DIR%" 2>nul
    cd /d "%PROJECT_DIR%"
    cd ..
    git clone https://github.com/solecithovallenato-netizen/snake-game.git
)

:: 4. Set memory
echo.
echo [4/4] 恢复 AI 记忆...
set "MEM_DIR=%USERPROFILE%\.claude\projects\C--Users-wzglo-Desktop-test\memory"
mkdir "%MEM_DIR%" 2>nul

(
echo ---
echo name: user_wang_zhenguang
echo description: 王振光个人信息
echo ---
echo 王振光，学号 202402210385，24计算机科学与技术4班，实训第4组。组员：胡翰斌、刘永涛、王浩乐。项目：政务数字门户平台POC，鲲鹏ARM+FusionCompute+Docker+Halo。
) > "%MEM_DIR%\user_wang_zhenguang.md"

(
echo ---
echo name: project-homework
echo description: 实训作业交付状态
echo ---
echo 所有交付物在 作业/交付物/ 下。部署命令：cd /opt/blog-platform ^&^& ./deploy.sh。详细步骤见 03-部署实施手册.docx。
) > "%MEM_DIR%\project-homework.md"

echo.
echo ==============================================
echo   部署完成！
echo ==============================================
echo.
echo   启动 Claude Code:
echo   cd /d "%PROJECT_DIR%"
echo   claude
echo.
echo   然后说："帮我部署博客" 即可继续
echo ==============================================
pause
