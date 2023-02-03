unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, pngimage,
  System.ImageList, Vcl.ImgList;

type
  TForm1 = class(TForm)
    BtnVL: TBitBtn;
    BtnVT: TBitBtn;
    BtnVR: TBitBtn;
    BtnVBT: TBitBtn;
    BtnVBK: TBitBtn;
    BtnVF: TBitBtn;
    BtnVP: TBitBtn;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    BitBtn3: TBitBtn;
    procedure BtnVLMouseEnter(Sender: TObject);
    procedure BtnVLMouseLeave(Sender: TObject);
  private
    { Private êÈåæ }
  public
    { Public êÈåæ }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.BtnVLMouseEnter(Sender: TObject);
begin
  if Sender is TBitBtn then
    Self.Tag := TBitBtn(Sender).Tag;
end;

procedure TForm1.BtnVLMouseLeave(Sender: TObject);
begin
  Self.Tag := 0;
end;

end.
