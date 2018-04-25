cd %WORKSPACE%/binaries/
cmd /c npm install
SET PATH=%PATH%";C:\Program Files\Java\jdk1.8.0_65\bin\"
@echo "build source files"
@echo below is the IP of the Jenkins
ipconfig
javac -cp org.junit.runner.JUnitCore;* *.java
::"C:\Program Files\Java\jdk1.8.0_65\bin\javac.exe" -cp org.junit.runner.JUnitCore;* *.java
@echo "compile test framework"
::"C:\Program Files\Java\jdk1.8.0_65\bin\jar.exe" -cvfm TestRunner.jar ../manifest.txt *.class
jar -cvfm TestRunner.jar ../manifest.txt *.class
@echo "run test framework"
::"C:\Program Files\Java\jdk1.8.0_65\bin\java.exe" -cp org.junit.runner.JUnitCore;* TestRunner
java -cp org.junit.runner.JUnitCore;* TestRunner