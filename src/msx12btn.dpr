program msx12btn;

// Ver.1.1
//   Creo���[�h�ESolidWorks���[�h�̐ؑ�
//
// Ver.1.2
//   SolidWorks�E�C���h�E�������F�������[�h��؂�ւ���
//
// Ver.1.3.00
//   Shift+X2�ł̃��f������mapkey����ύX�B
//   mapkey �֘A��creo��works�E�C���h�E�ȊO�Ō����Ȃ��悤�ɁB
//   ���[�h�ؑ�HotKey�p�~�B
//
// Ver.1.3.01
//   �p�X���[�h���͋@�\�ǉ��B���V�t�g�{X2Dbl
// Ver.1.3.02
//   CurrWin���ς��ƃo���[���ĕ\�������s��C���B
// Ver.1.3.03
//   �������͋@�\��IME OFF�@�\��ǉ��B
//
// Ver.2.0.00
//    Form�t VF,VR,VBT�Ȃǂ̃}�b�v�L�[�p
//
// Ver.2.1.00
//    ���[�h��L�[�ݒ��Ini�t�@�C���Őݒ�\�ɁB
//    �L���v�V�����m�F���[�h�ǉ�(ini��chkWindowMode=1)
//
// Ver.2.2.00
//    �p�X���[�h���͎��̃o���[���폜�B



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
    winType     : array[0..9] of string;  //�^�C�v�̖��O
    winCaption  : array[0..9] of string;  //���̕����̃E�C���h�E��T��
    szTip       : array[0..9] of string;  //toolTip�e�L�X�g
    X1, X2, X1d, X2d: array[0..9] of string; //�L�[�ݒ�
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
//  ���[�h�ؑւɂ��^�X�N�g���C�c�[���`�b�v�X�V
//-----------------------------------------------------------------------------
procedure ChangeToolTip;
begin

    StrPLCopy(NotifyIcon.szTip, PChar('<'+winType[actIdx]+' Mode>'#10+szTip[actIdx]), 255);

    //�g���C�A�C�R���̍X�V
    StrPLCopy(NotifyIcon.szInfo, PChar(''), 255);
    Shell_NotifyIcon(NIM_MODIFY, Addr(NotifyIcon));
end;


//-----------------------------------------------------------------------------
//IME��Ԃ�ύX
//-----------------------------------------------------------------------------
function SetImeStatus(Hdl: HWND; OnOff:boolean): boolean;
var
      IMC: HIMC;
begin
      IMC := ImmGetDefaultIMEWnd(Hdl);
      SendMessage(IMC, WM_IME_CONTROL, 6{IMC_SETOPENSTATUS}, Ord(OnOff));

      //��Ԃ��擾����ꍇ�͈ȉ��ŁB
      //if LongBool(SendMessage(IMC, WM_IME_CONTROL,
      //                        5{IMC_GETOPENSTATUS}, 0)) then begin
      //  result := True
      //end else begin
      //  result := False;
      //end;
      result:=True;
end;


//-----------------------------------------------------------------------------
//�o���[���\��
//-----------------------------------------------------------------------------
procedure Balloon(msg:string);
begin

    Shell_NotifyIcon(NIM_DELETE, Addr(NotifyIcon));
    StrPLCopy(NotifyIcon.szInfo, PChar(msg), 255);
    Shell_NotifyIcon(NIM_ADD, Addr(NotifyIcon));

end;


//-----------------------------------------------------------------------------
//  Window�L���v�V�����Ń��[�h�����ݒ�
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
//  �g���C�A�C�R���ƃz�b�g�L�[�̓o�^
//-----------------------------------------------------------------------------

procedure TrayIconTouroku;
var
    IniFile :TIniFile;
    i:integer;
  function conv(s:string): string; //���ꕶ�����L�[�R�[�h�ɕϊ����ĕԂ�
  begin
     //����L�[
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
      //Mouse�{�^��
      s := StringReplace(s, '<Left>',  #1, [rfReplaceAll, rfIgnoreCase]);//VK_LBUTTON
      s := StringReplace(s, '<Right>', #2, [rfReplaceAll, rfIgnoreCase]);//VK_RBUTTON
      s := StringReplace(s, '<Middle>',#4, [rfReplaceAll, rfIgnoreCase]);//VK_MBUTTON

      Result:=s;
  end;
begin
    //INI�t�@�C�����[�h
    IniFile := TIniFile.Create(ChangeFileExt(ParamStr(0),'.ini'));
    try
      //�p�X���[�h�Ǎ�
      chkWindowMode := IniFile.ReadBool('General', 'chkWindowMode', False);
      //Type���̐ݒ� �Ǎ�
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


    //�g���C�A�C�R���̏��̏�����
    FillChar(NotifyIcon, SizeOf(TNotifyIconData), #0);
    //�e�����ݒ�
    NotifyIcon.cbSize           := SizeOf(TNotifyIconData);
    NotifyIcon.Wnd              := Application.Handle;
    NotifyIcon.hIcon            := Application.Icon.Handle;
    NotifyIcon.uCallbackMessage := WM_APP + 110;
    NotifyIcon.uID              := 1;
    NotifyIcon.uFlags           := NIF_ICON or NIF_MESSAGE or NIF_TIP or NIF_INFO;// or NIF_REALTIME;
    NotifyIcon.uTimeout := 0;

    StrPLCopy(NotifyIcon.szTip, PChar(szTip[0]), 100);
    //�g���C�A�C�R���̓o�^
    Shell_NotifyIcon(NIM_ADD,Addr(NotifyIcon));

    ChangeToolTip;


    //�O���[�o���z�b�g�L�[(�V���[�g�J�b�g�L�[)�̓o�^
    //���C�����[�v�ŁAWM_HOTKEY ���Z�[�W������
    //�����ꍇ�͔z��̎g�p���ǂ�����

    //Ctrl+Shift+Q�F�I��
    SetKey1   := Ord('Q');
    SetShift1 := MOD_CONTROL or MOD_SHIFT;
    HotKeyID1 := GlobalAddAtom('MyHotkey1');
    RegisterHotKey(Application.Handle, HotKeyID1, SetShift1, SetKey1);

end;


//-----------------------------------------------------------------------------
//  ���b�Z�[�W�����p�E�B���h�E�v���V�[�W���[
//  [Ctrl]+[A]�L�[�ŏ풓�I��
//  �^�X�N�g���C�̖{�A�v���̃A�C�R����̃}�E�X�E�{�^�������Ń��b�Z�[�W��\��
// ss:keys
// caseSensitive: true,false
// state: 0:click, 1:down, 2:up
//-----------------------------------------------------------------------------
procedure KeyInput(ss:string; caseSensitive:boolean; state:integer; delay:integer=0);
var
    I, J: integer;
    needShift: boolean; //�����Őݒ肷��
    key: Cardinal;
    btn: Integer; //mousebutton 1=L,2=R,4=M
    CtrlKeys: array of byte; //Ctrl,Shift,Alt�Ȃ�
begin

    SetImeStatus(GetForegroundWindow(),false); //IME��OFF
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
      ord(#39): begin needShift:=true; key:=ord('7');      end; //�V���O���R�[�e�[�V����
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
        //����L�[
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

      //����L�[�̉���
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
//  ���b�Z�[�W�����p�E�B���h�E�v���V�[�W���[
//  �^�X�N�g���C�̖{�A�v���̃A�C�R����̃}�E�X�E�{�^�������Ń��b�Z�[�W��\��
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
        //�g���C�A�C�R���ŁC�}�E�X�E�{�^����������܂���.
          if (LParam = WM_LBUTTONDBLCLK)or(LParam = WM_RBUTTONDOWN)or(Msg = WM_HOTKEY) then begin
            ret:=MessageDlg('�ؖ{��p'#10'�}�E�XX1X2�{�^���u���c�[��'#10'Ver.'+VER+#10'���I�����܂����B',
                       mtInformation,
                       [mbYes,mbNo,mbRetry],
                       0);
            //�_�C�A���O��[X]�{�^���ŕ��Ă��܂����ꍇ�̑΍�
            //[X]�{�^����[Alt]+[F4]�ł͏풓���I�������Ȃ�
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
          //�}�E�X�{�^��DOWN-----------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          WM_XBUTTONDOWN, WM_NCXBUTTONDOWN:begin

              GetCursorPos(curPos);

            if LParam=MY_XBUTTON1 then begin
            //XBUTTON1�̓}�E�X��O���̃{�^��
          
                isX1down := True;

                if passwd_mode>0 then begin
                  passwd_mode:=0;
                  balloon('');
                end;

                KeyInput(X1[actIdx], false, MY_DOWN);

            end else


            if LParam=MY_XBUTTON2 then begin
            //XBUTTON2�̓}�E�X�����̃{�^��
          
                isX2down := True;
              
                //XBUTTON1�����Ȃ���̂Ƃ�, 3D���f�������ύX���[�h
                if isX1down and(DEF[actIdx]<>'') then begin
                  try
                    Form1.Left := curPos.X - Form1.BtnVR.Left + 12;
                    Form1.Top := curPos.y - Form1.BtnVBT.Top + 12;
                    Form1.Show;
                  except
                    PostQuitMessage(0);
                  end;
                  //X1���L�����Z��
                  KeyInput(X1[actIdx], false, MY_UP);

                end else begin
                  KeyInput(X2[actIdx], false, MY_DOWN);
                end;
            end;
          end;




          //---------------------------------------------------------
          //---------------------------------------------------------
          //---------------------------------------------------------
          //�}�E�X�{�^��UP-------------------------------------------
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
                  //�p�X���[�h����
                  KeyInput(pass[actIdx], true, MY_CLICK, wait[actIdx]);
                  passwd_mode:=0;
                end

                //XBUTTON 1�̃_�u���N���b�N (15px�ȓ��ŃN���b�N�����ꍇ�̂݁j
                else if (timer=MY_XBUTTON1)and(max(abs(curPos.X-tmpPos.X),abs(curPos.Y-tmpPos.Y))<15)and(X1d[actIdx]<>'') then begin
                  KillTimer(Application.Handle, MY_XBUTTON1);
                  timer:=0;
                  KeyInput(X1d[actIdx], false, MY_CLICK, wait[actIdx]);
                end

                //XBUTTON 1�̃V���O���N���b�N(�_�u���N���b�N�^�C�}�[�N��)
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
                  //X1�̃L�[���͂��L�����Z��
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
                  //XBUTTON 2�̃V���O���N���b�N
                  if timer<>MY_XBUTTON2 then begin
                    KeyInput(X2[actIdx], false, MY_UP);
                    timer:=MY_XBUTTON2;
                    SetTimer(Application.Handle, MY_XBUTTON2, GetDoubleClickTime()*2, nil);
                  end

                  //XBUTTON 2�̃_�u���N���b�N
                  else begin //���ԓ��ɃN���b�N�����̂�DBLCLK�Ƃ݂Ȃ�
                    KillTimer(Application.Handle, MY_XBUTTON2);
                    timer:=0;

                    if (max(abs(curPos.X-tmpPos.X),abs(curPos.Y-tmpPos.Y))<15) then begin

                      //if (passwd_mode>0) and (pass[actIdx]<>'') then begin
                      if isX1down and (pass[actIdx]<>'') then begin
                        passwd_mode:=1;

                        //pass_mode����T�b�ȓ�
                       // if (Now()-passwd_mode < StrToDateTime('0:0:5')) then begin
                          //Balloon('');
                          //keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
                          //keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
                          //sleep(500);
                          //�p�X���[�h����
                          //KeyInput(pass[actIdx], true, MY_CLICK, wait[actIdx]);
                       // end else
                       //   Balloon('');

                        //passwd_mode:=0;

                      //end else if false and isX1down and (pass[actIdx]<>'') then begin
                      //pass mode
                      //  Balloon(winType[actIdx]+#13'Input Password?');
                      //  passwd_mode:=Now();
                      end else begin
                      //�ʏ��dblclk
                        KeyInput(X2[actIdx], false, MY_UP);
                        KeyInput(X2d[actIdx], false, MY_CLICK);
                      end;

                    end;

                  end;
                end;
              end;

          end;

          WM_MOUSEHWHEEL: begin //���`���g������
              if LParam<0 then begin
                //mouse_event(MOUSEEVENTF_WHEEL,0,0,WHEEL_DELTA,0);
              end else begin
                //w := -1*WHEEL_DELTA;
                //mouse_event(MOUSEEVENTF_WHEEL,0,0,w,0);
              end;
          end;


        end;//case wparam
      end;//WM_APP+100

    WM_TIMER: //DblClick���o�p
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
//  �z�b�g�L�[�ƃg���C�A�C�R���̓o�^�폜
//-----------------------------------------------------------------------------
procedure TrayIconOwari;
begin
    //�O���p�[���z�b�g�L�[�̓o�^����
    GlobalDeleteAtom(HotkeyID1);
    UnRegisterHotKey(Application.Handle, HotKeyID1);

    //�g���C�A�C�R���̍폜
    Shell_NotifyIcon(NIM_DELETE, @NotifyIcon);
end;

//=============================================================================
//  1. �^�X�N�o�[�ɃA�v���̃A�C�R����\�����Ȃ�
//  2. ���C���t�H�[����\��(�쐬���Ă��Ȃ�)
//  3. ���b�Z�[�W���������邽�߂ɃE�B���h�E�v���V�[�W���[��u��������
//=============================================================================
begin
    //���b�Z�[�W�����̂��߂ɃA�v���̃E�B���h�E�v���V�[�W���[��u��������
    SetWindowLong(Application.Handle, GWL_WNDPROC, Integer(@MainAppProc));

    //Form1���쐬
    Application.Initialize;
    Application.MainFormOnTaskbar := False;
    //TStyleManager.TrySetStyle('Light');
    Application.CreateForm(TForm1, Form1);
    SetWindowLong(Application.Handle, GWL_EXSTYLE, WS_EX_TOOLWINDOW);

    //�g���C�A�C�R���o�^
    TrayIconTouroku;
    StartMouseKeyHook(Application.Handle);


    //�I���̃��b�Z�[�W������܂Ń��[�v
    while GetMessage(Msg, 0, 0, 0) do begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;
    TrayIconOwari;


    StopMouseKeyHook;
    //MessageDlg('�I���ł�', mtInformation, [mbOK], 0);
    System.Halt(Msg.wParam);
end.
