{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************
}
unit JumpHistoryView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, StdCtrls, Menus, LCLProc,
  CodeToolManager, CodeCache,
  IDEOptionDefs, EnvironmentOpts, IDEProcs, LazarusIDEStrConsts,
  Project, ProjectDefs;

type

  { TJumpHistoryViewWin }

  TJumpHistoryViewWin = class(TForm)
    listHistory : TListBox;
    procedure FormCreate(Sender : TObject);
    procedure FormDestroy(Sender : TObject);
    procedure listHistoryClick(Sender : TObject);
    procedure listHistoryDblClick(Sender : TObject);
    procedure OnIdle(Sender : TObject; var Done: Boolean);
  private
    { private declarations }
    fOnSelectionChanged : TNotifyEvent;
    fProjectChangeStamp: integer;
    function GetSelectedIndex : Integer;
    function BeautifyLine(const Filename: string; X, Y: integer;
      const Line: string): string;
    procedure InitDisplay;
  protected
    procedure IndexChanged(Sender: TObject; Index: Integer);
    procedure ListChanged(Sender: TObject; Index: Integer);
  public
    { public declarations }
    property SelectedIndex : Integer read GetSelectedIndex;
    property OnSelectionChanged: TNotifyEvent read fOnSelectionChanged
                                              write fOnSelectionChanged;
  end;

var
  JumpHistoryViewWin : TJumpHistoryViewWin = nil;

implementation

const
  MaxTextLen = 80;

{ TJumpHistoryViewWin }

procedure TJumpHistoryViewWin.FormCreate(Sender : TObject);
var
  ALayout: TIDEWindowLayout;
begin
  Caption := lisMenuViewJumpHistory;
  Name := NonModalIDEWindowNames[nmiwJumpHistory];
  ALayout:=EnvironmentOptions.IDEWindowLayoutList.
                                          ItemByEnum(nmiwJumpHistory);
  ALayout.Form:=TForm(Self);
  ALayout.Apply;
  
  Application.AddOnIdleHandler(@OnIdle);

  InitDisplay;
end;

procedure TJumpHistoryViewWin.FormDestroy(Sender : TObject);
begin

end;

procedure TJumpHistoryViewWin.listHistoryClick(Sender : TObject);
begin
  if EnvironmentOptions.MsgViewDblClickJumps then exit;
  if Assigned(fOnSelectionChanged) then fOnSelectionChanged(self);
end;

procedure TJumpHistoryViewWin.listHistoryDblClick(Sender : TObject);
begin
  if not EnvironmentOptions.MsgViewDblClickJumps then exit;
  if Assigned(fOnSelectionChanged) then fOnSelectionChanged(self);
end;

procedure TJumpHistoryViewWin.OnIdle(Sender: TObject; var Done: Boolean);
begin
  if (Project1<>nil)
  and (Project1.JumpHistory.ChangeStamp<>fProjectChangeStamp) then
    InitDisplay;
end;

function TJumpHistoryViewWin.GetSelectedIndex : Integer;
begin
  Result := listHistory.ItemIndex;
end;

function TJumpHistoryViewWin.BeautifyLine(const Filename : string; X, Y : integer;
  const Line : string) : string;
begin
  Result:=SpecialCharsToHex(Line);
  if UTF8Length(Result)>MaxTextLen then
    Result:=UTF8Copy(Result,1,MaxTextLen)+'...';
  Result:=Filename
          +' ('+IntToStr(Y)
          +','+IntToStr(X)+')'
          +' '+Result;
end;

procedure TJumpHistoryViewWin.InitDisplay;
var
  i : integer;
  jh_item : TProjectJumpHistoryPosition;
  SrcLine: String;
  CodeBuf: TCodeBuffer;
  Filename: String;
begin
  if (Project1<>nil)
  and (fProjectChangeStamp=Project1.JumpHistory.ChangeStamp) then exit;
  listHistory.Items.BeginUpdate;
  listHistory.Clear;
  if (Project1<>nil) then begin
    fProjectChangeStamp:=Project1.JumpHistory.ChangeStamp;
    for i := 0 to Project1.JumpHistory.Count -1 do begin
      jh_item := Project1.JumpHistory.Items[i];
      SrcLine:='';
      CodeBuf:=CodeToolBoss.LoadFile(jh_item.Filename,false,False);
      if CodeBuf<>nil then
        SrcLine:=CodeBuf.GetLine(jh_item.CaretXY.Y-1);
      Filename:=jh_item.Filename;
      if Project1<>nil then
        Project1.ShortenFilename(Filename);
      listHistory.Items.Append
        (BeautifyLine(Filename,
                      jh_item.CaretXY.X,
                      jh_item.CaretXY.Y,
                      SrcLine
                     )
        );
    end;
    DebugLn(['TJumpHistoryViewWin.InitDisplay Project1.JumpHistory.HistoryIndex=',Project1.JumpHistory.HistoryIndex]);
    listHistory.ItemIndex := Project1.JumpHistory.HistoryIndex;
  end;
  listHistory.Items.EndUpdate;
end;

procedure TJumpHistoryViewWin.IndexChanged(Sender : TObject; Index : Integer);
begin
  listHistory.ItemIndex := Project1.JumpHistory.HistoryIndex;
end;

procedure TJumpHistoryViewWin.ListChanged(Sender : TObject; Index : Integer);
begin
  InitDisplay;
end;


initialization
  {$I jumphistoryview.lrs}

end.

