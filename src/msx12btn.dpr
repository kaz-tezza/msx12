program msx12btn;

// Ver.1.1
//   Creoモード・SolidWorksモードの切替
//
// Ver.1.2
//   SolidWorksウインドウを自動認識しモードを切り替える
//
// Ver.1.3.00
//   Shift+X2でのモデル方向mapkey動作変更。
//   mapkey 関連をcreoやworksウインドウ以外で効かないように。
//   モード切替HotKey廃止。
//
// Ver.1.3.01
//   パスワード入力機能追加。左シフト＋X2Dbl
// Ver.1.3.02
//   CurrWinが変わるとバルーン再表示される不具合修正。
// Ver.1.3.03
//   文字入力機能でIME OFF機能を追加。
//
// Ver.2.0.00
//    Form付 VF,VR,VBTなどのマップキー用
//
// Ver.2.1.00
//    モードやキー設定をIniファイルで設定可能に。
//    キャプション確認モード追加(iniのchkWindowMode=1)
//
// Ver.2.2.00
//    パスワード入力時のバルーン削除。



uses
    Windows,
    Classes,
    Messages,
    SysUtils,
    Forms,
    ShellAPI,
    System.UITypes,
    Dialogs,
    Math,
    IniFiles,
    IMM,
    Unit1 in 'Unit1.pas' {Form1},
    Vcl.Themes,
    Vcl.Styles;

{$R *.res}

const VER = '2.2.00';

var
    Msg         : TMsg;
    NotifyIcon  : TNotifyIconData;
    HotKeyID1   : Integer;
    SetKey1     : Cardinal;
    SetShift1   : Cardinal;
    timer       : Integer;

    actIdx      : Integer; //active type (other=0, type1=1...)
    winType     : array[0..9] of string;  //タイプの名前
    winCaption  : array[0..9] of string;  //この文字のウインドウを探す
    szTip       : array[0..9] of string;  //toolTipテキスト
    X1, X2, X1d, X2d: array[0..9] of string; //キー設定
    VF  : array[0..9] of string;
    VL  : array[0..9] of string;
    VR  : array[0..9] of string;
    VBT : array[0..9] of string;
    VT  : array[0..9] of string;
    VBK : array[0..9] of string;
    VS  : array[0..9] of string;
    VV  : array[0..9] of string;
    VP  : array[0..9] of string;
    DEF : array[0..9] of string;
    pass: array[0..9] of string;
    wait: array[0..9] of integer;

    isX1down: boolean;
    isX2down: boolean;


    curPos :TPoint;
    passwd_mode    : TDateTime;
    cSizeAll: HCURSOR;
    Form1: TForm1;

    chkWindowMode:boolean;

const
    WM_XBUTTONDOWN   = $020B;
    WM_XBUTTONUP     = $020C;
    WM_NCXBUTTONDOWN = $00AB;
    WM_NCXBUTTONUP   = $00AC;
    WM_MOUSEHWHEEL   = $020E;
    NIF_INFO = $10;
    NIF_SHOWTIP = $80;

    MY_XBUTTON1 = 1;
    MY_XBUTTON2 = 2;

    MY_CLICK = 0;
    MY_DOWN = 1;
    MY_UP =2;

function StartMouseKeyHook(Wnd: HWND): HHOOK; stdcall; external 'ms45hook.DLL';
procedure StopMouseKeyHook; stdcall; external 'ms45hook.DLL';



//-----------------------------------------------------------------------------
//  モード切替によるタスクトレイツールチップ更新
//-----------------------------------------------------------------------------
procedure ChangeToolTip;
begin

    StrPLCopy(NotifyIcon.szTip, PChar('<'+winType[actIdx]+' Mode>'#10+szTip[actIdx]), 255);

    //トレイアイコンの更新
    StrPLCopy(NotifyIcon.szInfo, PChar(''), 255);
    Shell_NotifyIcon(NIM_MODIFY, Addr(NotifyIcon));
end;


//-----------------------------------------------------------------------------
//IME状態を変更
//-----------------------------------------------------------------------------
function SetImeStatus(Hdl: HWND; OnOff:boolean): boolean;
var
      IMC: HIMC;
begin
      IMC := ImmGetDefaultIMEWnd(Hdl);
      SendMessage(IMC, WM_IME_CONTROL, 6{IMC_SETOPENSTATUS}, Ord(OnOff));

      //状態を取得する場合は以下で。
      //if LongBool(SendMessage(IMC, WM_IME_CONTROL,
      //                        5{IMC_GETOPENSTATUS}, 0)) then begin
      //  result := True
      //end else begin
      //  result := False;
      //end;
      result:=True;
end;


//-----------------------------------------------------------------------------
//バルーン表示
//-----------------------------------------------------------------------------
procedure Balloon(msg:string);
begin

    Shell_NotifyIcon(NIM_DELETE, Addr(NotifyIcon));
    StrPLCopy(NotifyIcon.szInfo, PChar(msg), 255);
    Shell_NotifyIcon(NIM_ADD, Addr(NotifyIcon));

end;


//-----------------------------------------------------------------------------
//  Windowキャプションでモード自動設定
//-----------------------------------------------------------------------------
function getwin: boolean;
var
    hWindow :HWnd;
    PC   :PChar;
    Len  :integer;
    Name :string;
    CName :string;
//    tmpPos:TPoint;
    i:integer;
    newIdx: integer;
begin
 result:=false;

    hWindow :=GetForegroundWindow();
    //GetCursorPos(tmpPos) ;
    //hWindow := WindowFromPoint(tmpPos);
    if hWindow<>0 then begin
      //while GetParent(hWindow)<>0 do hWindow:=GetParent(hWindow);
      GetMem(PC, 255);
      Len := GetWindowtext(hWindow, PC, 255);
      setstring(Name, PC, Len);
      Len := GetClassName(hWindow, PC, 255);
      setstring(CName, PC, Len);
      if chkWindowMode then balloon('text = ' +name+#13#10'class = '+cname);
    end;

    newIdx:=0;
    for i := 1 to 9 do begin
      if(Pos(winCaption[i], Name)>0)then begin newIdx:=i;break;end;
    end;

    if newIdx<>actIdx then begin
      actIdx := newIdx;
      ChangeToolTip;
    end;

end;

//-----------------------------------------------------------------------------
//  トレイアイコンとホットキーの登録
//-----------------------------------------------------------------------------

procedure TrayIconTouroku;
var
    IniFile :TIniFile;
    i:integer;
  function conv(s:string): string; //特殊文字をキーコードに変換して返す
  begin
     //特殊キー
      s := StringReplace(s, 'Ctrl+',  #17, [rfReplaceAll, rfIgnoreCase]);//VK_CONTROL
      s := StringReplace(s, 'Shift+', #16, [rfReplaceAll, rfIgnoreCase]);//VK_SHIFT
      s := StringReplace(s, 'Alt+',   #18, [rfReplaceAll, rfIgnoreCase]);//VK_MENU
      s := StringReplace(s, 'Win+', #8091, [rfReplaceAll, rfIgnoreCase]);//VK_LWIN
      s := StringReplace(s, 'Ctrl',   #17, [rfReplaceAll, rfIgnoreCase]);//VK_CONTROL
      s := StringReplace(s, 'Shift',  #16, [rfReplaceAll, rfIgnoreCase]);//VK_SHIFT
      s := StringReplace(s, 'Alt',    #18, [rfReplaceAll, rfIgnoreCase]);//VK_MENU
      s := StringReplace(s, 'Win',  #8091, [rfReplaceAll, rfIgnoreCase]);//VK_LWIN
      s := StringReplace(s, '<0>',  #8096, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD0
      s := StringReplace(s, '<1>',  #8097, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD1
      s := StringReplace(s, '<2>',  #8098, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD2
      s := StringReplace(s, '<3>',  #8099, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD3
      s := StringReplace(s, '<4>',  #8100, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD4
      s := StringReplace(s, '<5>',  #8101, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD5
      s := StringReplace(s, '<6>',  #8102, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD6
      s := StringReplace(s, '<7>',  #8103, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD7
      s := StringReplace(s, '<8>',  #8104, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD8
      s := StringReplace(s, '<9>',  #8105, [rfReplaceAll, rfIgnoreCase]);//VK_NUMPAD9
      s := StringReplace(s, '<.>',  #8110, [rfReplaceAll, rfIgnoreCase]);//VK_DECIMAL
      s := StringReplace(s, '<Enter>',#13, [rfReplaceAll, rfIgnoreCase]);//VK_RETURN
      s := StringReplace(s, '<Esc>',  #27, [rfReplaceAll, rfIgnoreCase]);//VK_ESCAPE
      //Mouseボタン
      s := StringReplace(s, '<Left>',  #1, [rfReplaceAll, rfIgnoreCase]);//VK_LBUTTON
      s := StringReplace(s, '<Right>', #2, [rfReplaceAll, rfIgnoreCase]);//VK_RBUTTON
      s := StringReplace(s, '<Middle>',#4, [rfReplaceAll, rfIgnoreCase]);//VK_MBUTTON

      Result:=s;
  end;
begin
    //INIファイルロード
    IniFile := TIniFile.Create(ChangeFileExt(ParamStr(0),'.ini'));
    try
      //パスワード読込
      chkWindowMode := IniFile.ReadBool('General', 'chkWindowMode', False);
      //Type毎の設定 読込
      for i := 0 to 9 do begin
        winType[i]   := IniFile.ReadString('Type'+IntToStr(i), 'name', 'Other');
        winCaption[i]:= IniFile.ReadString('Type'+IntToStr(i), 'SearchWord', 'hogehoge');
        X1[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'X1', 'Shift'));
        X2[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'X2', 'Ctrl'));
        X1d[i]       := conv(IniFile.ReadString('Type'+IntToStr(i), 'X1d', ''));
        X2d[i]       := conv(IniFile.ReadString('Type'+IntToStr(i), 'X2d', ''));
        VF[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'VF', ''));
        VL[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'VL', ''));
        VR[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'VR', ''));
        VBT[i]       := conv(IniFile.ReadString('Type'+IntToStr(i), 'VBT',''));
        VT[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'VT', ''));
        VBK[i]       := conv(IniFile.ReadString('Type'+IntToStr(i), 'VBK',''));
        VS[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'VS', ''));
        VV[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'VV', ''));
        VP[i]        := conv(IniFile.ReadString('Type'+IntToStr(i), 'VP', ''));
        DEF[i]       := conv(IniFile.ReadString('Type'+IntToStr(i), 'DEF', ''));
        pass[i]      := conv(IniFile.ReadString('Type'+IntToStr(i), 'id_pass', ''));
        wait[i]      := IniFile.ReadInteger('Type'+IntToStr(i), 'delay', 0);

        szTip[i]  := 'X1:'+IniFile.ReadString('Type'+IntToStr(i), 'X1', 'Shift')+#10+
                     'X2:'+IniFile.ReadString('Type'+IntToStr(i), 'X2', 'Ctrl')+#10+
                     'X1d:'+IniFile.ReadString('Type'+IntToStr(i), 'X1d', '')+#10+
                     'X2d:'+IniFile.ReadString('Type'+IntToStr(i), 'X2d', '');
      end;
    finally
      IniFile.Free;
    end;


    //トレイアイコンの情報の初期化
    FillChar(NotifyIcon, SizeOf(TNotifyIconData), #0);
    //各種情報を設定
    NotifyIcon.cbSize           := SizeOf(TNotifyIconData);
    NotifyIcon.Wnd              := Application.Handle;
    NotifyIcon.hIcon            := Application.Icon.Handle;
    NotifyIcon.uCallbackMessage := WM_APP + 110;
    NotifyIcon.uID              := 1;
    NotifyIcon.uFlags           := NIF_ICON or NIF_MESSAGE or NIF_TIP or NIF_INFO;// or NIF_REALTIME;
    NotifyIcon.uTimeout := 0;

    StrPLCopy(NotifyIcon.szTip, PChar(szTip[0]), 100);
    //トレイアイコンの登録
    Shell_NotifyIcon(NIM_ADD,Addr(NotifyIcon));

    ChangeToolTip;


    //グローバルホットキー(ショートカットキー)の登録
    //メインループで、WM_HOTKEY メセージを処理
    //多い場合は配列の使用が良いかも

    //Ctrl+Shift+Q：終了
    SetKey1   := Ord('Q');
    SetShift1 := MOD_CONTROL or MOD_SHIFT;
    HotKeyID1 := GlobalAddAtom('MyHotkey1');
    RegisterHotKey(Application.Handle, HotKeyID1, SetShift1, SetKey1);

end;


//-----------------------------------------------------------------------------
//  メッセージ処理用ウィンドウプロシージャー
//  [Ctrl]+[A]キーで常駐終了
//  タスクトレイの本アプリのアイコン上のマウス右ボタン押下でメッセージを表示
// ss:keys
// caseSensitive: true,false
// state: 0:click, 1:down, 2:up
//-----------------------------------------------------------------------------
procedure KeyInput(ss:string; caseSensitive:boolean; state:integer; delay:integer=0);
var
    I, J: integer;
    needShift: boolean; //自動で設定する
    key: Cardinal;
    btn: Integer; //mousebutton 1=L,2=R,4=M
    CtrlKeys: array of byte; //Ctrl,Shift,Altなど
begin

    SetImeStatus(GetForegroundWindow(),false); //IMEをOFF
    SetLength(CtrlKeys, 0);

    for I := 1 to length(ss) do begin

      needShift:=false;
      key:=ord(ss[i]);
      btn:=0;

      case key of
      ord('A')..ord('Z'): begin needShift:=caseSensitive;  end;
      ord('a')..ord('z'): begin key:=ord(upperCase(ss)[i]);end;

      ord('0')..ord('9'):;
      ord('!'): begin needShift:=true; key:=ord('1');      end;
      ord('"'): begin needShift:=true; key:=ord('2');      end;
      ord('#'): begin needShift:=true; key:=ord('3');      end;
      ord('$'): begin needShift:=true; key:=ord('4');      end;
      ord('%'): begin needShift:=true; key:=ord('5');      end;
      ord('&'): begin needShift:=true; key:=ord('6');      end;
      ord(#39): begin needShift:=true; key:=ord('7');      end; //シングルコーテーション
      ord('('): begin needShift:=true; key:=ord('8');      end;
      ord(')'): begin needShift:=true; key:=ord('9');      end;


      ord('-'): key:=VK_OEM_MINUS;
      ord('.'): key:=VK_OEM_PERIOD;
      ord(','): key:=VK_OEM_COMMA;
      ord(';'): key:=VK_OEM_PLUS;
      ord(':'): key:=VK_OEM_1;
      ord('/'): key:=VK_OEM_2;
      ord('@'): key:=VK_OEM_3;
      ord('['): key:=VK_OEM_4;
      ord('\'): key:=VK_OEM_5;
      ord(']'): key:=VK_OEM_6;
      ord('^'): key:=VK_OEM_7;

      ord('='): begin needShift:=true; key:=VK_OEM_MINUS;  end;
      ord('>'): begin needShift:=true; key:=VK_OEM_PERIOD; end;
      ord('<'): begin needShift:=true; key:=VK_OEM_COMMA;  end;
      ord('+'): begin needShift:=true; key:=VK_OEM_PLUS;   end;
      ord('*'): begin needShift:=true; key:=VK_OEM_1;      end;
      ord('?'): begin needShift:=true; key:=VK_OEM_2;      end;
      ord('`'): begin needShift:=true; key:=VK_OEM_3;      end;
      ord('{'): begin needShift:=true; key:=VK_OEM_4;      end;
      ord('|'): begin needShift:=true; key:=VK_OEM_5;      end;
      ord('}'): begin needShift:=true; key:=VK_OEM_6;      end;
      ord('~'): begin needShift:=true; key:=VK_OEM_7;      end;
      ord('_'): begin needShift:=true; key:=VK_OEM_102;    end;

      ord(#1) : begin btn:=1;key:=0;end;
      ord(#2) : begin btn:=2;key:=0;end;
      ord(#4) : begin btn:=4;key:=0;end;

      8091..8110: key:=key - 8000;

      else
        //特殊キー
        SetLength(CtrlKeys, Length(CtrlKeys)+1);
        CtrlKeys[Length(CtrlKeys)-1]:=key;
        if state<2 then keybd_event(key, 0, 0, 0);
        key:=0;
        if I<length(ss) then Continue;
      end;

      if btn>0 then begin
      //mouse button
        if state=0 then begin //click
          if btn=1 then mouse_event(MOUSEEVENTF_LEFTDOWN,0,0,0,0);
          if btn=1 then mouse_event(MOUSEEVENTF_LEFTUP,0,0,0,0);
          if btn=2 then mouse_event(MOUSEEVENTF_RIGHTDOWN,0,0,0,0);
          if btn=2 then mouse_event(MOUSEEVENTF_RIGHTUP,0,0,0,0);
          if btn=3 then mouse_event(MOUSEEVENTF_MIDDLEDOWN,0,0,0,0);
          if btn=3 then mouse_event(MOUSEEVENTF_MIDDLEDOWN,0,0,0,0);
        end else if state=1 then begin //down
          if btn=1 then mouse_event(MOUSEEVENTF_LEFTDOWN,0,0,0,0);
          if btn=2 then mouse_event(MOUSEEVENTF_RIGHTDOWN,0,0,0,0);
          if btn=4 then mouse_event(MOUSEEVENTF_MIDDLEDOWN,0,0,0,0);
        end else if state=2 then begin //up
          if btn=1 then mouse_event(MOUSEEVENTF_LEFTUP,0,0,0,0);
          if btn=2 then mouse_event(MOUSEEVENTF_RIGHTUP,0,0,0,0);
          if btn=4 then mouse_event(MOUSEEVENTF_MIDDLEUP,0,0,0,0);
        end;
      end else if key>0 then begin
      //keyboard
        if state=0 then begin //click
          if needShift then keybd_event(VK_SHIFT, 0, 0, 0);
          keybd_event(key, 0, 0, 0);
          keybd_event(key, 0, KEYEVENTF_KEYUP, 0);
          if needShift then keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
        end else if state=1 then begin //down
          if needShift then keybd_event(VK_SHIFT, 0, 0, 0);
          keybd_event(key, 0, 0, 0);
        end else if state=2 then begin //up
          keybd_event(key, 0, KEYEVENTF_KEYUP, 0);
          if needShift then keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
        end;
      end;

      //特殊キーの解除
      if state<>1 then begin
        for J := Length(CtrlKeys)-1 downto 0 do begin
            keybd_event(CtrlKeys[J], 0, KEYEVENTF_KEYUP, 0);
        end;
      end;
      SetLength(CtrlKeys, 0);
      if delay>0 then sleep(delay);
    end;

end;

//-----------------------------------------------------------------------------
//  メッセージ処理用ウィンドウプロシージャー
//  タスクトレイの本アプリのアイコン上のマウス右ボタン押下でメッセージを表示
//-----------------------------------------------------------------------------
function MainAppProc(hWindow: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM):
    LRESULT; stdcall; export;
var
    ret:integer;
    tmpPos:TPoint;
    mapkey:string;
begin
    Result := 0;

    case Msg of
{    WM_HOTKEY:
        begin
          if HIWORD(LPARAM)=Ord('Q') then
            PostQuitMessage(0);
          //else
            //ChangeToolTip;
        end;
}
    WM_APP + 110,WM_HOTKEY:
       begin
        //トレイアイコンで，マウス右ボタンが押されました.
          if (LParam = WM_LBUTTONDBLCLK)or(LParam = WM_RBUTTONDOWN)or(Msg = WM_HOTKEY) then begin
            ret:=MessageDlg('木本専用'#10'マウスX1X2ボタン置換ツール'#10'Ver.'+VER+#10'を終了しますか。',
                       mtInformation,
                       [mbYes,mbNo,mbRetry],
                       0);
            //ダイアログを[X]ボタンで閉じてしまった場合の対策
            //[X]ボタンと[Alt]+[F4]では常駐を終了させない
            Result := 1;
            if ret=mrYes then PostQuitMessage(0);
            if ret=mrRetry then begin
              ShellExecute(0, 'open', PChar(ExtractFileDir(ParamStr(0))), PChar(''), nil, SW_SHOW);
              ShellExecute(0, 'open', PChar(ParamStr(0)), PChar(''), nil, SW_SHOW);
              PostQuitMessage(0);
            end;
          end;

          //if (LParam = WM_LBUTTONDBLCLK) then ChangeToolTip;
        end;

    WM_APP + 100:
      begin
        getwin;

        case WParam of

          //---------------------------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          //マウスボタンDOWN-----------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          WM_XBUTTONDOWN, WM_NCXBUTTONDOWN:begin

              GetCursorPos(curPos);

            if LParam=MY_XBUTTON1 then begin
            //XBUTTON1はマウス手前側のボタン
          
                isX1down := True;

                if passwd_mode>0 then begin
                  passwd_mode:=0;
                  balloon('');
                end;

                KeyInput(X1[actIdx], false, MY_DOWN);

            end else


            if LParam=MY_XBUTTON2 then begin
            //XBUTTON2はマウス奥側のボタン
          
                isX2down := True;
              
                //XBUTTON1押しながらのとき, 3Dモデル方向変更モード
                if isX1down and(DEF[actIdx]<>'') then begin
                  try
                    Form1.Left := curPos.X - Form1.BtnVR.Left + 12;
                    Form1.Top := curPos.y - Form1.BtnVBT.Top + 12;
                    Form1.Show;
                  except
                    PostQuitMessage(0);
                  end;
                  //X1をキャンセル
                  KeyInput(X1[actIdx], false, MY_UP);

                end else begin
                  KeyInput(X2[actIdx], false, MY_DOWN);
                end;
            end;
          end;




          //---------------------------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          //マウスボタンUP-------------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          WM_XBUTTONUP, WM_NCXBUTTONUP: begin
              GetCursorPos(tmpPos);

              //XButton1
              if LParam=MY_XBUTTON1 then begin

                isX1down := false;

                KeyInput(X1[actIdx], false, MY_UP);
                //beep;
                if passwd_mode>0 then begin
                  keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
                  keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
                  sleep(300);
                  //パスワード入力
                  KeyInput(pass[actIdx], true, MY_CLICK, wait[actIdx]);
                  passwd_mode:=0;
                end

                //XBUTTON 1のダブルクリック (15px以内でクリックした場合のみ）
                else if (timer=MY_XBUTTON1)and(max(abs(curPos.X-tmpPos.X),abs(curPos.Y-tmpPos.Y))<15)and(X1d[actIdx]<>'') then begin
                  KillTimer(Application.Handle, MY_XBUTTON1);
                  timer:=0;
                  KeyInput(X1d[actIdx], false, MY_CLICK, wait[actIdx]);
                end

                //XBUTTON 1のシングルクリック(ダブルクリックタイマー起動)
                else begin
                  timer:=MY_XBUTTON1;
                  curPos:=tmpPos;
                  SetTimer(Application.Handle, MY_XBUTTON1, GetDoubleClickTime()*2, nil);
                end;

              end

              //XBUTTON 2
              else if LParam=MY_XBUTTON2 then begin

                isX2down := false;

                if Form1.Visible then begin
                  Form1.Hide;
                  KillTimer(Application.Handle, MY_XBUTTON2);
                  timer:=0;
                  //X1のキー入力をキャンセル
                  KeyInput(X1[actIdx], false, MY_UP);
                  SystemParametersInfo(SPI_SETCURSORS, 0, nil, 0);

                  case Form1.Tag of
                    1:mapkey:=VF[actIdx];
                    2:mapkey:=VL[actIdx];
                    3:mapkey:=VR[actIdx];
                    4:mapkey:=VBT[actIdx];
                    5:mapkey:=VT[actIdx];
                    6:mapkey:=VBK[actIdx];
                    7:mapkey:=VS[actIdx];
                    8:mapkey:=VV[actIdx];
                    9:mapkey:=VP[actIdx];
                   10:mapkey:=DEF[actIdx];
                    else
                    mapkey:='';
                  end;

                  if mapkey<>''  then begin
                    //Balloon(mapkey);
                    KeyInput(mapkey, false, MY_CLICK, wait[actIdx]);
                  end;

                end

                else begin
                  //XBUTTON 2のシングルクリック
                  if timer<>MY_XBUTTON2 then begin
                    KeyInput(X2[actIdx], false, MY_UP);
                    timer:=MY_XBUTTON2;
                    SetTimer(Application.Handle, MY_XBUTTON2, GetDoubleClickTime()*2, nil);
                  end

                  //XBUTTON 2のダブルクリック
                  else begin //時間内にクリックしたのでDBLCLKとみなす
                    KillTimer(Application.Handle, MY_XBUTTON2);
                    timer:=0;

                    if (max(abs(curPos.X-tmpPos.X),abs(curPos.Y-tmpPos.Y))<15) then begin

                      //if (passwd_mode>0) and (pass[actIdx]<>'') then begin
                      if isX1down and (pass[actIdx]<>'') then begin
                        passwd_mode:=1;

                        //pass_modeから５秒以内
                       // if (Now()-passwd_mode < StrToDateTime('0:0:5')) then begin
                          //Balloon('');
                          //keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
                          //keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
                          //sleep(500);
                          //パスワード入力
                          //KeyInput(pass[actIdx], true, MY_CLICK, wait[actIdx]);
                       // end else
                       //   Balloon('');

                        //passwd_mode:=0;

                      //end else if false and isX1down and (pass[actIdx]<>'') then begin
                      //pass mode
                      //  Balloon(winType[actIdx]+#13'Input Password?');
                      //  passwd_mode:=Now();
                      end else begin
                      //通常のdblclk
                        KeyInput(X2[actIdx], false, MY_UP);
                        KeyInput(X2d[actIdx], false, MY_CLICK);
                      end;

                    end;

                  end;
                end;
              end;

          end;

          WM_MOUSEHWHEEL: begin //横チルト無効化
              if LParam<0 then begin
                //mouse_event(MOUSEEVENTF_WHEEL,0,0,WHEEL_DELTA,0);
              end else begin
                //w := -1*WHEEL_DELTA;
                //mouse_event(MOUSEEVENTF_WHEEL,0,0,w,0);
              end;
          end;


        end;//case wparam
      end;//WM_APP+100

    WM_TIMER: //DblClick検出用
      begin
        KillTimer(Application.Handle, wParam);
        timer:=0;
      end
    else
      begin
        Result := DefWindowProc( hWindow, Msg, wParam, lParam );
      end;
    end;


end;

//-----------------------------------------------------------------------------
//  ホットキーとトレイアイコンの登録削除
//-----------------------------------------------------------------------------
procedure TrayIconOwari;
begin
    //グロパールホットキーの登録解除
    GlobalDeleteAtom(HotkeyID1);
    UnRegisterHotKey(Application.Handle, HotKeyID1);

    //トレイアイコンの削除
    Shell_NotifyIcon(NIM_DELETE, @NotifyIcon);
end;

//=============================================================================
//  1. タスクバーにアプリのアイコンを表示しない
//  2. メインフォーム非表示(作成していない)
//  3. メッセージを処理するためにウィンドウプロシージャーを置き換える
//=============================================================================
begin
    //メッセージ処理のためにアプリのウィンドウプロシージャーを置き換える
    SetWindowLong(Application.Handle, GWL_WNDPROC, Integer(@MainAppProc));

    //Form1を作成
    Application.Initialize;
    Application.MainFormOnTaskbar := False;
    //TStyleManager.TrySetStyle('Light');
    Application.CreateForm(TForm1, Form1);
    SetWindowLong(Application.Handle, GWL_EXSTYLE, WS_EX_TOOLWINDOW);

    //トレイアイコン登録
    TrayIconTouroku;
    StartMouseKeyHook(Application.Handle);


    //終了のメッセージがくるまでループ
    while GetMessage(Msg, 0, 0, 0) do begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;
    TrayIconOwari;


    StopMouseKeyHook;
    //MessageDlg('終了です', mtInformation, [mbOK], 0);
    System.Halt(Msg.wParam);
end.
