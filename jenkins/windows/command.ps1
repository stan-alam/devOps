npm install -g newman-reporter-htmlextra
$Env:PASSWORD=''
$Env:GUID_01 =''
$Env:GUID_02 =''
$Env:USERNAME=''
$Env:TESTENV=${env:ENVY}
$Env:AUTH=${env:ENVY}

Write-Host "============================="
Write-Host "Password:    " $Env:PASSWORD
Write-Host "UserName:    " $Env:USERNAME
Write-Host "TestEnv:     " $Env:TESTENV
Write-Host "authEndPoint:" $Env:AUTH
Write-Host "============================="

  If ($Env:AUTH  -eq 'SUT-01')  {

  'This is SUT-01'

echo "this is the working dir "
echo $pwd

cd E2E\

((Get-Content -Path Test-API.json) -replace 'TESTENV',$Env:TESTENV -replace 'authEndPoint',$Env:AUTH) | Set-Content -Path Test-API.json
newman run Test-API.json --env-var "=$Env:GUID_01" -r htmlextra --reporter-htmlextra-export

     If ($LASTEXITCODE -ne 0) {
     $E2E = 1
     echo "e2e failed"

  } Else {

echo "running second run"
}
cd ..
cd path01\path02\

((Get-Content -Path TEST-02.json) -replace 'TESTENV',$Env:TESTENV -replace 'authEndPoint',$Env:AUTH) | Set-Content -Path TEST-02.json
newman run TEST-02.json --env-var "guide_02=$Env:GUID_02" -r htmlextra --reporter-htmlextra-export

  If ($LASTEXITCODE -ne 0) {
      $second_test = 1
      echo "second test suite failed"
  } Else {

 echo "Running third test suite"
}
cd ..
cd path\third_test

((Get-Content -Path Test-API.json) -replace 'TESTENV',$Env:TESTENV -replace 'authEndPoint',$Env:AUTH) | Set-Content -Path Test-API.json
newman run Test-API.json --env-var "=$Env:GUID_01" -r htmlextra --reporter-htmlextra-export

  If ($LASTEXITCODE -ne 0) {
     $third_test = 1
    echo "third test suite failed"
  } Else {

 echo "running 4th test suite"
}
cd ..
cd ..
cd path\fourth_test

((Get-Content -Path Test-API.json) -replace 'TESTENV',$Env:TESTENV -replace 'authEndPoint',$Env:AUTH) | Set-Content -Path Test-API.json
newman run Test-API.json --env-var "=$Env:GUID_01" -r htmlextra --reporter-htmlextra-export

    If ($LASTEXITCODE -ne 0) {
     $fourth_test = 1
    echo "fourth testSuite failed"

     } Else {

      echo "evaluating test results"
    }

    $test = $E2E + $second_test + $third_test + $fourth_test
    echo "this is the final test result " + $test
    If ($test -ne 0) {
      exit(1)

    } Else {

  echo "tests have passed!"
}

  }  ElseIf ($Env:AUTH  -eq 'another_SUT')  {

  'This is another SUT'
cd E2E\
((Get-Content -Path Test-API.json) -replace 'TESTENV',$Env:TESTENV -replace 'authEndPoint',$Env:AUTH) | Set-Content -Path Test-API.json
newman run Test-API.json --env-var "=$Env:GUID_01" -r htmlextra --reporter-htmlextra-export

  }  Else {

  'error'
   exit(1)

}
