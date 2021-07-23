@echo OFF

set CAPTIONERPATH=%1\captioner\

rem Define the path to conda installation
set CONDAPATH=C:\ProgramData\Anaconda3
rem Define the path to the conda environments
set ENVFOLD=C:\Users\%USERNAME%\.conda\
rem Define the name of the environment
set ENVNAME=LightroomCV

set ENVPATH=%ENVFOLD%\envs\%ENVNAME%

rem Activate the conda environment
call %CONDAPATH%\Scripts\activate.bat %ENVPATH%

rem Start captioner
python %CAPTIONERPATH%\captioner_service.py %CAPTIONERPATH%
echo %CAPTIONERPATH%

rem Deactivate the environment
call conda deactivate

pause
exit