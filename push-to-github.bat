@echo off
echo Pushing SlightBuild to GitHub...
echo.
cd /d "C:\Users\tcole\Desktop\Claude_Projects\SlightSites\SlightBuild"
echo Current directory:
cd
echo.
echo Pushing to GitHub (you'll need to enter your credentials)...
git push -u origin main
echo.
echo Push complete! Check https://github.com/slightbuild/slightbuild-website
pause