@ECHO OFF
CHCP 65001 > NUL
SETLOCAL ENABLEDELAYEDEXPANSION
MODE 80,22
:: ==== Package_Versions == ::
SET cURL_v=7.70.0
SET jq_v=1.6
SET sed_v=4.8
:: ==== Setting_Variables ==== ::
(SET \N=^
%=_Empty_Line_=%
)
SET /A "Req_pakN=4, Blog_Cnt=Category_Cnt=TxtPostCnt=0"
SET "NCA_Fname=NCA_Folder"
SET "Req_pak=  7za, curl, sed, jq,"
IF %PROCESSOR_ARCHITECTURE% == AMD64 (
	SET PA=64
	SET PA_7za=x64
	SET PA_sed=x64
) ELSE (
	SET PA=32
	SET PA_7za=ia32
	SET PA_sed=xp
)
SET STY_S=NAIV
SET UsePostListInfo=false
:: ==== Prepare_Before ==== ::
SET "NCA_P=%~DP0!NCA_Fname!\Packages"
SET "NCA_T=%~DP0!NCA_Fname!\Temp"
FOR %%A IN ("%~DP0!NCA_Fname!" "!NCA_P!" "!NCA_T!") DO (
	IF NOT EXIST "%%A\" MD "%%A" || GOTO ERROR_FC
)
CD /D "!NCA_P!"
FOR %%A IN ("%Systemroot%\System32" "!NCA_P!") DO (
	IF EXIST "%%~A\curl.exe" (
		SET "cURL_p=%%~A"
		"%%~A\curl.exe" -V | FIND "Features:" | FIND "libz" > NUL
		IF !ERRORLEVEL! EQU 0 (
			SET Req_pakN=3
			SET "Req_pak=!Req_pak: curl,=!"
		)
	)
)
FOR %%A IN (%Req_pak%) DO (
	IF EXIST %%A.exe (
		SET "Req_pak=!Req_pak: %%A,=!"
		SET /A Req_pakN-=1
	)
)
:: ==== Prepare_Start ==== ::
TITLE Naver_Blog Category Article Collector
IF %Req_pakN% NEQ 0 (
	ECHO ------------------------------------------------------------
	ECHO  Required Packages[%Req_pakN%] :%Req_pak:~0,-1%!\N!!\N!  - 패키지 다운로드를 시작합니다.
	SET /P "W=---------------------------------------" < NUL
	FOR %%A IN (%Req_pak%) DO (
		ECHO !\N! - [다운로드] %%A 패키지 다운로드 중...
		CALL :Package_%%A
		IF !ERRORLEVEL! EQU 1 (
			CALL :ERROR_DN %%A
			EXIT /B
		)
	)
	ECHO  - 모든 패키지 다운로드가 완료되었습니다.
)
:: == MAiN == ::
:MAiN
CLS & MODE 70,22
ECHO ----------------------------------------------------------------------!\N!
ECHO                     네이버 카테고리 글 목록 수집기!\N!
ECHO       ^|   선택지  ^| =========================================!\N!!\N!
ECHO        ^|  1  ^|  블로그의 전체 글 목록 수집!\N!!\N!
ECHO        ^|  2  ^|  특정 카테고리의 글 목록 수집!\N!!\N!
ECHO        ^|  3  ^|  직접 수집할 카테고리 설정 입력!\N!!\N!
ECHO       =======================================================!\N!
ECHO ----------------------------------------------------------------------
SET /P SEL=선택지를 입력하십시요:
FOR /L %%A IN (1,1,3) DO IF "!SEL!" == "%%A" GOTO SEL_listStyle
CALL :ERROR_CS 2
GOTO MAiN
:SEL_listStyle
ECHO !\N!-------------------------------
ECHO 수집할 글의 유형을 선택하세요.
ECHO ============================!\N!
ECHO   ^|  1  ^|  모든 유형의 글!\N!
ECHO   ^|  2  ^|  사진을 포함한 글!\N!
ECHO   ^|  3  ^|  동영상을 포함한 글!\N!
ECHO -------------------------------!\N!* 2,3번 선택지는 스크랩된 글을 포함하지 않습니다.
SET /P STY=선택지를 입력하십시요:
SET /A STY_T=STY
FOR %%A IN (PostListInfo,ThumbnailPostListInfo,VideoPostList) DO (
	IF "!STY_T!" == "1" (
		SET URL_STY=%%A
		IF %SEL% EQU 3 (SETLOCAL & GOTO CategoryInfo_blogId) ELSE GOTO SEL_Address
	)
	SET /A STY_T-=1
)
CALL :ERROR_CS 1
GOTO MAiN
:SEL_Address
ECHO !\N!--------------------------------------------------
ECHO 수집할 글의 주소을 입력하세요.
ECHO ================================================
ECHO 블로그 글 주소나 카테고리 목록 주소를 입력하십시요.
ECHO 마우스 우클릭으로 주소를 붙여놓을 수 있습니다.
ECHO -------------------------------
SET /P URL=주소를 입력하십시요:
IF DEFINED URL IF NOT "!URL!" == "!URL:blog.naver.com=!" GOTO URL_PARSE
ECHO !\N!주소가 올바르지 않습니다.
TIMEOUT.EXE 1 /NOBREAK > NUL
GOTO MAiN
:: == Parse_Start == ::
:URL_PARSE
IF "!URL:PostList.nhn?=!" == "!URL:PostView.nhn?=!" (
	FOR /F "TOKENS=1,2 DELIMS=/" %%A IN ("!URL:*blog.naver.com/=!") DO (
		SET "URL_blogId=%%A"
		FOR /F %%C IN ('ECHO "%%B"^| sed.exe -n "s/^.\([0-9]\+\).*/\1/p"') DO SET "URL_logNo=%%C"
		GOTO URL_CHK
	)
)
FOR /F %%A IN ('ECHO "!URL!"^| sed.exe -n "s/.*[?&]blogId=\([[:alnum:]]\+\).*/\1/p"') DO SET "URL_blogId=%%A"
FOR %%A IN (logNo categoryNo) DO (
	FOR /F %%B IN ('ECHO "!URL!"^| sed.exe -n "s/.*[?&]%%A=\([0-9]\+\).*/\1/p"') DO IF NOT DEFINED URL_%%A SET "URL_%%A=%%B"
)

:URL_CHK
IF NOT DEFINED URL_blogId (
	CALL :ERROR_NI "!URL!"
	GOTO MAiN
)
IF NOT DEFINED URL_categoryNo (
	IF NOT DEFINED URL_logNo (
		CALL :ERROR_CF
		GOTO MAiN
	)
	FOR /F %%A IN ('curl.exe -s https://m.blog.naver.com/!URL_blogId!/!URL_logNo! ^| sed.exe -n "s/^categoryNo=.\([0-9]\+\).$/\1/p"') DO SET URL_categoryNo=%%A
)
:: == Category_Info == ::
:URL_Info_C
SETLOCAL
ECHO !\N!카테고리 정보를 불러오는 중...
DEL /Q "!NCA_T!\*"
FOR /F "TOKENS=*" %%A IN ('curl.exe -s "https://m.blog.naver.com/rego/BlogInfo.nhn?blogId=!URL_blogId!" --compressed -H "Referer: https://m.blog.naver.com/PostList.nhn" ^| jq.exe -R "fromjson? | .result | .blogName,.displayNickName"') DO (
	SET /A Blog_Cnt+=1
	SET "URL_BInfo!Blog_Cnt!=%%~A"
)
curl.exe -s "https://m.blog.naver.com/rego/CategoryList.nhn?blogId=!URL_blogId!" -H "Referer: https://m.blog.naver.com/PostList.nhn" -o "!NCA_T!\CategoryList_!URL_blogId!.json"
IF "!URL_categoryNo!" == "0" (
	SET URL_CInfo2=전체글
	FOR /F %%A IN ('jq.exe -R "fromjson? | .result.mylogPostCount" "!NCA_T!\CategoryList_!URL_blogId!.json"') DO SET URL_CInfo3=%%A
) ELSE FOR /F "TOKENS=*" %%A IN ('jq.exe -R "fromjson? | .result.mylogCategoryList[] | select(.categoryNo==!URL_categoryNo!) | .parentCategoryNo,.categoryName,.postCnt" "!NCA_T!\CategoryList_!URL_blogId!.json"') DO (
	SET /A Category_Cnt+=1
	SET "URL_CInfo!Category_Cnt!=%%~A"
)
IF DEFINED URL_CInfo1 IF NOT "!URL_CInfo1!" == "null" (
	FOR /F "TOKENS=*" %%A IN ('jq.exe -R "fromjson? | .result.mylogCategoryList[] | select(.categoryNo==!URL_CInfo1!).categoryName" "!NCA_T!\CategoryList_!URL_blogId!.json"') DO (
		SET "URL_CInfo5=%%~A"
	)
) ELSE SET URL_CInfo1=
SET Category_Cnt=2
curl.exe -s "https://m.blog.naver.com/rego/%URL_STY%.nhn?blogId=!URL_blogId!&categoryNo=%URL_categoryNo%&currentPage=1&logCode=0" --compressed -H "Referer: https://m.blog.naver.com/PostList.nhn" -o "!NCA_T!\%URL_STY%_!URL_blogId!(!STY_S:~%STY%,1!)-1.json"
FOR /F "TOKENS=*" %%A IN ('jq.exe -R "fromjson? | .result | .categoryName,.totalCount,.totalPage" "!NCA_T!\%URL_STY%_!URL_blogId!(!STY_S:~%STY%,1!)-1.json"') DO (
	SET "URL_CInfo!Category_Cnt!=%%~A"
	SET /A Category_Cnt+=1
)
IF !STY! LEQ 2 (SET "Title_V=titleWithInspectMessage") ELSE (SET "Title_V=title")
IF /I NOT %UsePostListInfo% == true IF %STY% LEQ 1 GOTO URL_Info_M
FOR /F %%A IN ('jq.exe -R "fromjson? | .result.postViewList[]?.logNo" "!NCA_T!\%URL_STY%_!URL_blogId!(!STY_S:~%STY%,1!)-1.json" ^| sed.exe -n "$="') DO SET PostListCnt=%%A

:URL_Info_M
CLS
ECHO ----------------------------------------------------------------------
ECHO   카테고리 정보
ECHO ----------------------------------------------------------------------
ECHO   블로그 이름        ^| "!URL_BInfo1!"
ECHO   블로그 계정 정보   ^| "!URL_BInfo2!"
ECHO   카테고리 이름/번호 ^| "!URL_CInfo2![%URL_categoryNo%]"
ECHO   카테고리 글 수(!STY_S:~%STY%,1!)  ^| "!URL_CInfo3!"
IF DEFINED URL_CInfo1 ECHO   상위 카테고리      ^| "!URL_CInfo5![!URL_CInfo1!]"
ECHO !\N! --------------------------------------------------------------------
ECHO     카테고리의 최근 글:
ECHO  --------------------------------------------------------------------
jq.exe -Rr "fromjson? | .result.postViewList[0,1,2,3,4]? | \"   \(.addDate/1000 ^| strftime(\"%%Y-%%m-%%d\")) ^| \(.%Title_V%)\"" "!NCA_T!\%URL_STY%_!URL_blogId!(!STY_S:~%STY%,1!)-1.json"
ECHO  --------------------------------------------------------------------
ECHO ----------------------------------------------------------------------
SET /P ListGo=해당 카테고리의 목록을 수집할까요?(Y,N):
IF /I "!ListGo!" == "Y" GOTO URL_Collect
IF /I NOT "!ListGo!" == "N" TIMEOUT.EXE 1 /NOBREAK > NUL & GOTO URL_Info_M
:URL_Info_S
ECHO !\N!------------------------------------------
ECHO  다른 선택지를 선택해주십시요.
ECHO ========================================!\N!
ECHO   ^|  1  ^|  시작 화면으로 이동!\N!
ECHO   ^|  2  ^|  카테고리 정보로 돌아가기!\N!
ECHO   ^|  3  ^|  수집할 카테고리 직접 설정!\N!
IF DEFINED URL_CInfo1 ECHO   ^|  4  ^|  상위 카테고리 수집!\N!
ECHO ---------------------------------------
SET /P SEL_C=선택지를 입력하십시요:
IF "!SEL_C!" EQU "1" ENDLOCAL & GOTO MAiN
IF "!SEL_C!" EQU "3" GOTO CategoryInfo_blogId
IF DEFINED URL_CInfo1 IF "!SEL_C!" EQU "4" (
	FOR %%A IN (!URL_CInfo1!) DO (
		ENDLOCAL
		SET "URL_categoryNo=%%A"
	)
	GOTO URL_Info_C
)
IF "!SEL_C!" NEQ "2" CALL :ERROR_CS 2
GOTO URL_Info_M
:: == Category_Collect == ::
:URL_Collect
IF EXIST "%~DP0!NCA_Fname!\CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].txt" (
	IF EXIST "%~DP0!NCA_Fname!\CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].bak" DEL "%~DP0!NCA_Fname!\CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].bak"
	REN "%~DP0!NCA_Fname!\CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].txt" "CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].bak"
)
CLS & MODE CON COLS=73
ECHO -------------------------------------------------------------------------
ECHO   ◈ 카테고리 목록 수집을 시작합니다...!\N!
ECHO   [아이디/블로그 이름]: !URL_blogId!/!URL_BInfo1!
ECHO   [카테고리 이름/번호]: !URL_CInfo2!/!URL_categoryNo!
ECHO   [카테고리 글 수/totalPage]: !URL_CInfo3!/!URL_CInfo4!
ECHO   [주소 형식]: https://blog.naver.com/AccountId/logId
ECHO   [파일 이름]: "CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].txt"!\N!
ECHO -------------------------------------------------------------------------
ECHO    카테고리 수집 현황:
ECHO =========================================================================
IF %STY% LEQ 1 IF /I NOT %UsePostListInfo% == true GOTO URL_Collect_PostTitleList
:URL_Collect_PostList
FOR /L %%A IN (1,1,%URL_CInfo4%) DO (
	FOR /F %%B IN ('curl.exe -s "https://m.blog.naver.com/rego/%URL_STY%.nhn?blogId=!URL_blogId!&categoryNo=!URL_categoryNo!&currentPage=%%A&logCode=0" --compressed -H "Referer: https://m.blog.naver.com/PostList.nhn" ^| jq.exe -R "fromjson? | .result.postViewList[]?.logNo"') DO ECHO https://blog.naver.com/!URL_blogId!/%%~B>> "%~DP0!NCA_Fname!\CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].txt"
	IF %%A EQU %URL_CInfo4% (SET /A TxtPostCnt=URL_CInfo3) ELSE (SET /A TxtPostCnt+=PostListCnt)
	FOR %%C IN ("%~DP0!NCA_Fname!\CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].txt") DO CALL :FileSize Txtb %%~ZC
	ECHO  # 진행도^(페이지^): %%A/%URL_CInfo4% ^| 진행도^(글 수^): !TxtPostCnt!/!URL_CInfo3! ^| 파일 크기: !Txtb!
)
GOTO URL_Collected
:URL_Collect_PostTitleList
SET /A "URL_CInfo4=URL_CInfo3/30+1, URL_CInfo4F=URL_CInfo3%%30"
IF !URL_CInfo4F! EQU 0 SET /A URL_CInfo4-=1
FOR /L %%A IN (1,1,%URL_CInfo4%) DO (
	FOR /F "USEBACK" %%B IN (`curl.exe -s "https://blog.naver.com/PostTitleListAsync.nhn?blogId=!URL_blogId!&currentPage=%%A&categoryNo=!URL_categoryNo!&countPerPage=30" --compressed -H "Referer: https://blog.naver.com/PostList.nhn" ^| sed.exe "s/\\'//g" ^| jq.exe ".postList[]?.logNo"`) DO ECHO https://blog.naver.com/!URL_blogId!/%%~B>> "%~DP0!NCA_Fname!\CategoryList(A)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].txt"
	IF %%A EQU %URL_CInfo4% (SET /A TxtPostCnt=URL_CInfo3) ELSE (SET /A TxtPostCnt+=30)
	FOR %%C IN ("%~DP0!NCA_Fname!\CategoryList(A)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].txt") DO CALL :FileSize Txtb %%~ZC
	ECHO  # 진행도^(페이지^): %%A/%URL_CInfo4% ^| 진행도^(글 수^): !TxtPostCnt!/!URL_CInfo3! ^| 파일 크기: !Txtb!
)
:URL_Collected
ECHO -------------------------------------------------------------------------
ECHO  # 카테고리 수집이 완료되었습니다.
START "" "NOTEPAD.EXE" "%~DP0!NCA_Fname!\CategoryList(!STY_S:~%STY%,1!)_!URL_blogId!-!URL_CInfo2![!URL_categoryNo!].txt"
TIMEOUT.EXE 10 /NOBREAK
ENDLOCAL & GOTO MAiN
:: == Category_Setting == ::
:CategoryInfo_blogId
CLS
ECHO ----------------------------------------------------------------------
ECHO   카테고리 설정
ECHO ----------------------------------------------------------------------
ECHO   이 카테고리 설정에서 수집할 카테고리를 직접 설정할 수 있습니다.
ECHO   값을 변경할 설정에서 바꿀 값을 입력하고 ENTER을 누르십시요.
ECHO   아무 것도 입력하지 않고 ENTER을 누르면 기존의 값이 유지됩니다.!\N!
ECHO   잘못된 값을 입력할 경우 이 스크립트가 제대로 작동하지 않을 수도!\N!  있습니다.
ECHO !\N!--------------------------------------------------------------------
ECHO    블로그 아이디(네이버 계정 ID):
ECHO --------------------------------------------------------------------
ECHO    블로그의 계정 아이디입니다.!\N!   기존 값: !URL_blogId!!\N!
SET /P URL_blogId=변경할 값을 입력하십시요:
ECHO "!URL_blogId:&=!"| sed.exe "/^\".*[^^[:alnum:]].*\"$/q5" > NUL
IF !ERRORLEVEL! EQU 0 IF "!URL_blogId!" == "!URL_blogId:&=!" GOTO CategoryInfo_categoryNo
ECHO !\N!변경한 값이 숫자나 알파벳이 아닌 문자를 포함하고 있습니다.
TIMEOUT.EXE 2 /NOBREAK > NUL & GOTO CategoryInfo_blogId
:CategoryInfo_categoryNo
ECHO !\N!--------------------------------------------------------------------
ECHO    카테고리 ID:
ECHO --------------------------------------------------------------------
ECHO    카테고리의 고유한 숫자 ID입니다.!\N!   기존 값: !URL_categoryNo!!\N!
SET /P URL_categoryNo=변경할 값을 입력하십시요:
ECHO "!URL_categoryNo:&=!"| sed.exe "/^\".*[^^0-9].*\"$/q5" > NUL
IF !ERRORLEVEL! EQU 0 IF "!URL_categoryNo!" == "!URL_categoryNo:&=!" GOTO CategoryInfo_Postlist
ECHO !\N!변경한 값이 숫자가 아닌 문자를 포함하고 있습니다.
TIMEOUT.EXE 2 /NOBREAK > NUL & GOTO CategoryInfo_categoryNo
:CategoryInfo_Postlist
ECHO !\N!--------------------------------------------------------------------
ECHO    PostListInfo 사용:
ECHO --------------------------------------------------------------------
ECHO    모든 유형의 글을 수집할 때 강제로 PostListInfo.nhn을 사용하도록!\N!   설정합니다.
ECHO    이는 기본값인 PostTitleListAsync.nhn보다 느립니다.
ECHO    PostListInfo를 사용하려면 값을 true로 설정하십시요.!\N!   기존 값: !UsePostListInfo!!\N!
SET /P UsePostListInfo=변경할 값을 입력하십시요:
IF /I NOT "!UsePostListInfo!" == "false" IF /I NOT "!UsePostListInfo!" == "true" (
	ECHO !\N!변경한 값이 true나 false가 아닙니다.
	TIMEOUT.EXE 2 /NOBREAK > NUL & GOTO CategoryInfo_Postlist
)
ECHO ----------------------------------------------------------------------
ECHO 설정이 완료되었습니다.
FOR /F "TOKENS=1-3 DELIMS=$" %%A IN ("!URL_blogId!$!URL_categoryNo!$!UsePostListInfo!") DO (
	ENDLOCAL
	SET URL_blogId=%%A
	SET URL_categoryNo=%%B
	SET UsePostListInfo=%%C
)
GOTO URL_Info_C
:: == Packages == ::
:Package_7za
CALL :Pk_DN https://raw.githubusercontent.com/develar/7zip-bin/master/win/%PA_7za%/7za.exe "!NCA_P!\7za.exe"
IF %ERRORLEVEL% EQU 0 (EXIT /B) ELSE EXIT /B 1

:Package_curl
SETLOCAL
CALL :Pk_DN https://raw.githubusercontent.com/chocolatey-community/chocolatey-coreteampackages/master/automatic/curl/curl.nuspec "!NCA_T!\curl.nuspec"
IF %ERRORLEVEL% EQU 0 (
	FOR /F "TOKENS=3 DELIMS=<>" %%A IN ('FIND /I "</version>" ^< "!NCA_T!\curl.nuspec"') DO SET "cURL_v=%%A,%cURL_v%"
)
FOR %%A IN (%cURL_v%) DO (
	CALL :Pk_DN https://curl.haxx.se/windows/dl-%%A/curl-%%A-win%PA%-mingw.zip "!NCA_T!\curl-win.zip"
	IF !ERRORLEVEL! NEQ 0 (ENDLOCAL & EXIT /B 1) ELSE ENDLOCAL
)
:Package_curl_Unzip
ECHO  - [압축해제] curl 패키지 압축해제 중...
7za.exe e "!NCA_T!\curl-win.zip" -o"!NCA_P!" bin\ -r
SET "cURL_p=!NCA_P!"
IF %ERRORLEVEL% EQU 0 (EXIT /B) ELSE EXIT /B 1

:Package_sed
curl.exe https://raw.githubusercontent.com/mbuilov/sed-windows/master/sed-%sed_v%-%PA_sed%.exe -o "!NCA_P!\sed.exe"
IF %ERRORLEVEL% EQU 0 (EXIT /B) ELSE EXIT /B 1

:Package_jq
curl.exe -Lk https://github.com/stedolan/jq/releases/download/jq-%jq_v%/jq-win%PA%.exe -o "!NCA_P!\jq.exe"
IF %ERRORLEVEL% EQU 0 (EXIT /B) ELSE EXIT /B 1
:: ==== Errors ==== ::
:ERROR_FC
ECHO [ERROR] 폴더 생성 실패
ECHO - 폴더를 생성할 수 없습니다.
PAUSE > NUL
EXIT /B
:ERROR_DN
ECHO [ERROR] 패키지 다운로드(및 압축해제) 중 에러 발생
ECHO - 에러가 발생한 패키지: %1
PAUSE > NUL
EXIT /B
:ERROR_NI
ECHO [ERROR] 주소 분석 실패
ECHO - 분석이 실패한 주소: "%~1"
TIMEOUT.EXE 5 /NOBREAK > NUL
EXIT /B
:ERROR_CF
ECHO [ERROR] 파싱된 주소에서 카테고리 정보를 얻을 수 없음
ECHO 전체 글 목록을 수집하려면 시작 화면에서 선택지 1번을 선택하세요.
TIMEOUT.EXE 5 /NOBREAK > NUL
EXIT /B
:ERROR_CS
ECHO !\N!선택지가 올바르지 않습니다.
TIMEOUT.EXE %1 /NOBREAK > NUL
EXIT /B
:: ==== Scripts ==== ::
:Pk_DN
IF DEFINED cURL_p (
	curl.exe %1 -o "%~2"
	IF !ERRORLEVEL! EQU 0 (EXIT /B) ELSE EXIT /B 1
)
:BITS_DN
FOR /F %%A IN ('COPY /Z "%~DPF0" NUL') DO SET "CR=%%A"
FOR /F %%B IN ('ECHO PROMPT $H ^| CMD') DO SET "BS=%%B"
IF NOT "%~2" == "" IF [%3] == [] GOTO BITS_SET
ECHO USAGE: CALL :BITS_DN "<URL>" "<FILE>"
ENDLOCAL & EXIT /B 1
:BITS_SET
SET "FiLEN=%~NX2       "
ECHO Downloading "%~1"!\N!
BITSADMIN.EXE /cancel BITS_DN_LiTE > NUL
BITSADMIN.EXE /create /Download BITS_DN_LiTE > NUL
BITSADMIN.EXE /AddFile BITS_DN_LiTE "%~1" "%~DPNX2" > NUL
BITSADMIN.EXE /SetNoProgressTimeout BITS_DN_LiTE 3 > NUL
BITSADMIN.EXE /Resume BITS_DN_LiTE > NUL
ECHO  ^|  File Name     ^| Tot F ^| Status          ^| File Progress         ^|!\N! +================+=======+=================+=======================+
:BITS_QUEUED
:BITS_CONNECTING
:BITS_TRANSIENT_ERROR
:BITS_TRANSFERRING
FOR /F "TOKENS=1-9" %%A IN ('BITSADMIN.EXE /RawReturn /Info BITS_DN_LiTE') DO (
	SET "Stat=%%C          "
	CALL :FileSize Rb %%G
	CALL :FileSize Tb %%I
	SET "Tot_P=!Rb! / !Tb!      "
	SET /P "W=%BS% |  %FiLEN:~0,12%  | %%D / %%F | !Stat:~0,15! | !Tot_P:~0,21! |!CR!" < NUL
	PATHPING.EXE 127.0.0.1 -n -q 1 -p 250 > NUL
	GOTO BITS_%%C
)
:BITS_TRANSFERRED
BITSADMIN.EXE /complete BITS_DN_LiTE > NUL
ECHO !\N!!\N!File "%~NX2" saved in "%~DP2"
ENDLOCAL & EXIT /B
:BITS_ERROR
ECHO !\N!!\N!%DATE% %TIME% [CAUTION] - Error occurred
BITSADMIN.EXE /RawReturn /GetError BITS_DN_LiTE
:BITS_SUSPENDED
ECHO !\N!!\N!%DATE% %TIME% [ERROR] - Couldn't continue download
BITSADMIN.EXE /cancel BITS_DN_LiTE > NUL
ECHO Download aborted.
ENDLOCAL & EXIT /B 1

:FileSize
SET %1_int=%2
FOR %%A IN (KiB MiB) DO (
	IF !%1_int! LSS 1048576 (
		SET /A "%1_frac=%1_int%%1024*10/1024, %1_int/=1024"
		SET "%1=!%1_int!.!%1_frac!%%A"
		EXIT /B
	)
	SET /A %1_int/=1024
)