unit UnitMouseHook;

interface

uses
  Windows, Messages;

//�O���̃A�v���P�[�V��������g�p����֐���
function StartMouseKeyHook(Wnd: HWND): Boolean; stdcall;
procedure StopMouseKeyHook; stdcall;

implementation


const
  WM_XBUTTONDOWN   = $020B;
  WM_XBUTTONUP     = $020C;
  WM_NCXBUTTONDOWN = $00AB;
  WM_NCXBUTTONUP   = $00AC;
  //WM_MOUSEWHEEL    = $020A;
  WM_MOUSEHWHEEL   = $020E;
  WH_MOUSE_LL = 14;

//���L�������̓��e�̍\����
type
  PHookInfo  = ^THookInfo;
  THookInfo  = record
  HookMouseHandle : HHOOK;
  HostWnd         : HWND;
  end;

  PMSLLHOOKSTRUCT = ^MSLLHOOKSTRUCT;
  MSLLHOOKSTRUCT = record
    pt: TPOINT;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ^ULONG;
  end;


var
  //�������}�b�v�h�t�@�C���̃n���h��
  hMapFile : THandle;

const
  //�������}�b�v�h�t�@�C����
  MapFileName = 'HookMouseDLL';

//-----------------------------------------------------------------------------
//  ���L�������A�N�Z�X�̂��߂̏���
//
//  ���������0��Ԃ�.���s����ƕ�����Ԃ�.
//  ���̒l�ŏ����𕪊�ł���悤�ɂȂ��Ă��邪,���̃R�[�h�ł͖��g�p.
//-----------------------------------------------------------------------------
function MapFileMemory(var hMap: THandle; var pMap: pointer): Integer;
begin
  //�������}�b�v�h�t�@�C�����J��
  hMap := OpenFileMapping(FILE_MAP_ALL_ACCESS, False, MapFileName);
  if hMap = 0 then begin
    Result := -1;
    exit;
  end;

  //�������}�b�v�h�t�@�C���̊��蓖��
  pMap := MapViewOfFile(hMap, FILE_MAP_ALL_ACCESS, 0, 0, 0);
  if pMap = nil then begin
    Result := -2;
    CloseHandle(hMap);
    exit;
  end;

  Result := 0;
end;

//-----------------------------------------------------------------------------
//  ���L�������A�N�Z�X�̌�n��
//  �����Ă�������������΃r���[������
//  �n���h��������΃N���[�Y
//-----------------------------------------------------------------------------
procedure UnMapFileMemory(hMap: THandle; pMap: Pointer);
begin
  if pMap <> nil then UnmapViewOfFile(pMap);
  if hMap <> 0 then CloseHandle(hMap);
end;



//-----------------------------------------------------------------------------
//  �}�E�X�t�b�N�̃R�[���o�b�N�֐�
//  ����DLL���g�p�����A�v���Ƀ��b�Z�[�W�𑗂�
//-----------------------------------------------------------------------------
function MouseHookProc(nCode:integer; wPar: WPARAM; lPar: LPARAM): LRESULT; stdcall;
var
  LpMap   : Pointer;
  LMapWnd : THANDLE;
  xbutton:integer;
begin
  Result := 0;
  if MapFileMemory(LMapWnd, LpMap) <> 0 then exit;

  if nCode < 0 then begin
    Result := CallNextHookEx(pHookInfo(LpMap)^.HookMouseHandle, nCode, wPar, lPar);
  end else begin
    if (nCode = HC_ACTION)then begin
      case wPar of
        WM_XBUTTONDOWN, WM_NCXBUTTONDOWN, WM_XBUTTONUP, WM_NCXBUTTONUP:begin
          xbutton := PMSLLHOOKSTRUCT(lPar)^.mouseData shr 16;
          PostMessage(pHookInfo(LpMap)^.HostWnd, WM_APP+100, wPar, xbutton);
          Result := 1;
        end;
        WM_MOUSEHWHEEL:begin
          xbutton := PMSLLHOOKSTRUCT(lPar)^.mouseData;
          PostMessage(pHookInfo(LpMap)^.HostWnd, WM_APP+100, wPar, xbutton);
          Result := 1;
        end
{
        WM_MOUSEMOVE:begin
          Result := CallNextHookEx(pHookInfo(LpMap)^.HookMouseHandle, nCode, wPar, lPar);
        end;

        WM_MBUTTONDOWN, WM_MBUTTONUP:begin
          PostMessage(pHookInfo(LpMap)^.HostWnd, WM_APP+100, wPar, 0);
          Result := CallNextHookEx(pHookInfo(LpMap)^.HookMouseHandle, nCode, wPar, lPar);
        end
}
        else begin
          //xbutton := PMSLLHOOKSTRUCT(lPar)^.mouseData;
          //PostMessage(pHookInfo(LpMap)^.HostWnd, WM_APP+100, wPar, xbutton);
          Result := CallNextHookEx(pHookInfo(LpMap)^.HookMouseHandle, nCode, wPar, lPar);
        end;
      end;
    end;
  end;

  UnMapFileMemory(LMapWnd, LpMap);
end;

//-----------------------------------------------------------------------------
//  �t�b�N�֐��̓o�^
//-----------------------------------------------------------------------------
function StartMouseKeyHook(Wnd: HWND): Boolean; stdcall;
var
  LpMap   : Pointer;
  LMapWnd : THandle;
begin
  Result := False;

  //�������}�b�v�h�t�@�C���g�p����
  MapFileMemory(LMapWnd, LpMap);
  if LpMap = nil then begin
    LMapWnd := 0;
    exit;
  end;

  //�t�b�N���\���̏������ƃt�b�N�֐��̓o�^
  pHookInfo(LpMap)^.HostWnd := Wnd;
  //�t�b�N���C���X�g�[��
  pHookInfo(LpMap)^.HookMouseHandle := SetWindowsHookEx(WH_MOUSE_LL,
                                                    @MouseHookProc,
                                                    hInstance,
                                                    0);

  //�t�b�N����
  if (pHookInfo(LpMap)^.HookMouseHandle > 0) then begin
    Result := True;
  end;

  //�������}�b�v�h�t�@�C���g�p�I������
  UnMapFileMemory(LMapWnd, LpMap);
end;

//-----------------------------------------------------------------------------
//  �t�b�N�̉���
//-----------------------------------------------------------------------------
procedure StopMouseKeyHook; stdcall;
var
  LpMap   : Pointer;
  LMapWnd : THandle;
begin
  //�������}�b�v�h�t�@�C���g�p����
  MapFileMemory(LMapWnd, LpMap);
  if LpMap = nil then begin
    LMapWnd := 0;
    exit;
  end;

  //�t�b�N����
  if pHookInfo(LpMap)^.HookMouseHandle > 0 then begin
    UnhookWindowsHookEx(pHookInfo(LpMap)^.HookMouseHandle);
  end;

  //�������}�b�v�h�t�@�C���g�p�I������
  UnMapFileMemory(LMapWnd, LpMap);
end;

//-----------------------------------------------------------------------------
//  ���j�b�g��������
//  �������}�b�v�h�t�@�C���̍쐬
//
//  High(NativeUInt)�̒l��
//  32�r�b�g�A�v���ł�$FFFFFFFF
//  64�q�b�g�A�v���ł�$FFFFFFFFFFFFFFFF
//-----------------------------------------------------------------------------
initialization
begin
  hMapFile := CreateFileMapping(High(UInt),
                                nil,
                                PAGE_READWRITE,
                                0,
                                SizeOf(THookInfo),
                                MapFileName);
end;

//-----------------------------------------------------------------------------
//  ���j�b�g�I��������
//  �������}�b�v�h�t�@�C���̃N���[�Y
//-----------------------------------------------------------------------------
finalization
begin
  if hMapFile<>0 then CloseHandle(hMapFile);
end;

end.

