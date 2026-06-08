@echo off
echo ========================================
echo   Claude Code 一键部署脚本
echo   政务数字门户平台 POC 项目
echo ========================================
echo.

:: 1. Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [1/4] Node.js 未安装，请先下载安装：https://nodejs.org
    echo   推荐 v18+ LTS 版本
    pause
    exit /b 1
)
echo [1/4] Node.js OK:
node --version

:: 2. Install Claude Code
echo.
echo [2/4] 安装 Claude Code...
call npm install -g @anthropic-ai/claude-code
if %errorlevel% neq 0 (
    echo 安装失败，请检查网络
    pause
    exit /b 1
)
echo Claude Code 安装完成

:: 3. Clone project
echo.
echo [3/4] 克隆项目...
if exist "snake-game" (
    echo 项目目录已存在，跳过克隆
) else (
    call git clone https://github.com/solecithovallenato-netizen/snake-game.git
)
cd snake-game

:: 4. Restore memory
echo.
echo [4/4] 恢复 AI 记忆...

set MEMORY_DIR=%USERPROFILE%\.claude\projects\C--Users-wzglo-Desktop-test\memory
mkdir "%MEMORY_DIR%" 2>nul

echo - [自主视觉分析](feedback_autonomous_vision.md) > "%MEMORY_DIR%\MEMORY.md"
echo - [手势旋转惯性](feedback_gesture_rotation_inertia.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [Snake 部署架构](project_snake_deployment.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [localtunnel 不可靠](feedback_tunnel_bash_unreliable.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [调试反模式](feedback_debugging_speed.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [APIYI GPT Image 2](reference_apiyi_gpt_image2.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [CC-Connect 微信桥接](project_cc_connect_weixin.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [王振光个人信息](user_wang_zhenguang.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [实验日期用北京时间当天](feedback_experiment_date.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [手势沙盒架构](gesture-sandbox-architecture.md) >> "%MEMORY_DIR%\MEMORY.md"
echo - [照片3D系统](gesture-photo-3d.md) >> "%MEMORY_DIR%\MEMORY.md"

echo.
echo ========================================
echo   部署完成！
echo ========================================
echo.
echo  cd snake-game
echo  claude
echo.
echo  直接说"帮我部署博客"即可继续
echo ========================================
pause
