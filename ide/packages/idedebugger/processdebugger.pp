{ $Id$ }
{      ------------------------------------------------  
       ProcessDebugger.pp  -  Debugger class which only
                              executes a target 
       ------------------------------------------------ 
 
 @created(Sun Nov 27st WET 2005)
 @lastmod($Date$)
 @author(Marc Weustink <marc@@dommelstein.net>)                       

 This unit contains the process debugger class. It simply creates a process.
 
 
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
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************
}
unit ProcessDebugger;

{$mode objfpc}
{$H+}

interface

uses
  Classes, SysUtils, process,
  // LCL
  Dialogs, {$IFDEF LCLWin} Win32Proc, {$ENDIF}

  // LazUtils
  FileUtil, UTF8Process, LazFileUtils, LazLoggerBase,
  // DebuggerIntf
  DbgIntfDebuggerBase, DbgIntfProcess, LazDebuggerIntfBaseTypes,
  // IDE
  ProcessList, Debugger;

type

  { TProcessDebugger }

  TProcessDebugger = class(TDebugger)
  private
    FProcess: TProcessWithRedirect;
    FUseConsoleWinPos: boolean;
    FUseConsoleWinSize: boolean;
    FUseConsoleWinBuffer: boolean;
    FConsoleWinPos: TPoint;
    FConsoleWinSize: TPoint;
    FConsoleWinBuffer: TPoint;
    procedure ProcessDestroyed(Sender: TObject);
    function  ProcessEnvironment(const {%H-}AVariable: String; const {%H-}ASet: Boolean): Boolean;
    function  ProcessRun: Boolean;
    function  ProcessStop: Boolean;
  protected
    class function  GetSupportedCommands: TDBGCommands; override;
    function  RequestCommand(const ACommand: TDBGCommand; const AParams: array of const;
      const {%H-}ACallback: TMethod): Boolean; override;
  public
    class function Caption: String; override;
    class function NeedsExePath: boolean; override;
    class function SupportedFeatures: TDBGFeatures; override;
    procedure SetConsoleWinPos(ALeft, ATop: Integer); override;
    procedure UnSetConsoleWinPos; override;
    procedure SetConsoleWinSize(AWidth, AHeight: Integer); override;
    procedure UnSetConsoleWinSize; override;
    procedure SetConsoleWinBuffer(AColumns, ARows: Integer); override;
    procedure UnSetConsoleWinBuffer; override;
  published
  end;

implementation

type

  { TDBGProcess }

  TDBGProcess = class(TProcessWithRedirect)
  private
    FOnDestroy: TNotifyEvent;
  protected
  public
    destructor Destroy; override;
    property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy;
  end;

{ TDBGProcess }

destructor TDBGProcess.Destroy;
begin
  if Assigned(FOnDestroy) then FOnDestroy(Self);
  inherited Destroy;
end;


{ TProcessDebugger }

procedure TProcessDebugger.ProcessDestroyed(Sender: TObject);
begin
  FProcess := nil;

  LockRelease;
  try
    if State <> dsIdle then
      SetState(dsStop);
  finally
    UnlockRelease;
  end;
end;

function TProcessDebugger.ProcessEnvironment(const AVariable: String; const ASet: Boolean): Boolean;
begin
  // We don't have to do anything, we'll use the Environment when running
  Result := True;
end;

function TProcessDebugger.ProcessRun: Boolean;
begin
  DebugLn('PR: %s %s', [FileName, Arguments]);

  if FProcess <> nil
  then begin
    MessageDlg('Debugger', Format('There is already a process running: %s', [FProcess.{%H-}CommandLine]), mtError, [mbOK], 0);
    Result := False;
    Exit;
  end;

  SetState(dsInit);
  FProcess := TDBGProcess.Create(nil);
  try
    TDBGProcess(FProcess).OnDestroy := @ProcessDestroyed;
    GetDefaultProcessList.Add(FProcess);

    FProcess.Executable := FileName;
    SplitCmdLineParams(Arguments,FProcess.Parameters);
    FProcess.CurrentDirectory := WorkingDir;
    FProcess.Environment.Assign(Environment);
    if ShowConsole
    then FProcess.Options:= [poNewConsole]
    else FProcess.Options:= [poNoConsole];
    FProcess.ShowWindow := swoShowNormal;
    {$IFDEF windows}
    if FUseConsoleWinPos then begin
      FProcess.StartupOptions := FProcess.StartupOptions + [suoUsePosition];
      FProcess.WindowLeft   := FConsoleWinPos.X;
      FProcess.WindowTop    := FConsoleWinPos.Y;
    end;
    if FUseConsoleWinSize then begin
      FProcess.StartupOptions := FProcess.StartupOptions + [suoUseSize];
      FProcess.WindowWidth    := FConsoleWinSize.X;
      FProcess.WindowHeight   := FConsoleWinSize.Y;
    end;
    if FUseConsoleWinBuffer then begin
      FProcess.StartupOptions := FProcess.StartupOptions + [suoUseCountChars];
      FProcess.WindowColumns := FConsoleWinBuffer.X;
      FProcess.WindowRows    := FConsoleWinBuffer.Y;
    end;
    {$ENDIF}
    if DBG_PROCESS_HAS_REDIRECT then begin
      FProcess.SetRedirection(dtStdIn,  FileNameStdIn,  FileOverwriteStdIn);
      if (FileNameStdOut = FileNameStdErr) then begin
        if FileNameStdOut <> '' then begin
          FProcess.SetRedirection(dtStdOut, FileNameStdOut, FileOverwriteStdOut or FileOverwriteStdErr);
          FProcess.Options := FProcess.Options + [poStdErrToOutPut];
        end;
      end
      else begin
        FProcess.SetRedirection(dtStdOut, FileNameStdOut, FileOverwriteStdOut);
        FProcess.SetRedirection(dtStdErr, FileNameStdErr, FileOverwriteStdErr);
      end;

      {$IFDEF LCLWin}
      if (WindowsVersion > wvUnknown) and (WindowsVersion <= wv7) then
        FProcess.ApplyWin7Fix;
      {$ENDIF}
    end;

    FProcess.Execute;
  except
    on E: exception do begin
      MessageDlg('Debugger', Format('Exception while creating process: %s', [E.Message]), mtError, [mbOK], 0);
      Result := False;
      SetState(dsIdle);
      Exit;
    end;
  end;

  SetState(dsRun);
  Result := True;
end;

function TProcessDebugger.ProcessStop: Boolean;
begin
  FProcess.Terminate(0);
  // Do not free the process, the processlist will free it
  // FreeAndNil(FProcess);

  // SetState(dsStop);
  Result := True;
end;

class function TProcessDebugger.GetSupportedCommands: TDBGCommands;
begin
  Result := [dcRun, dcStop, dcEnvironment]
end;

function TProcessDebugger.RequestCommand(const ACommand: TDBGCommand;
  const AParams: array of const; const ACallback: TMethod): Boolean;
begin
  case ACommand of
    dcRun:         Result := ProcessRun;
    dcStop:        Result := ProcessStop;
    dcEnvironment: Result := ProcessEnvironment(String(APArams[0].VAnsiString), AParams[1].VBoolean);
    else Result := False;
  end;
end;

class function TProcessDebugger.Caption: String;
begin
  Result := '(none)';
end;

class function TProcessDebugger.NeedsExePath: boolean;
begin
  Result := false; // no need to have a valid exe path for the process debugger
end;

class function TProcessDebugger.SupportedFeatures: TDBGFeatures;
begin
  Result := inherited SupportedFeatures;
  {$IFDEF windows}
  Result := Result + [dfConsoleWinPos];
  {$ENDIF}
  if DBG_PROCESS_HAS_REDIRECT then
    Result := Result + [dfStdInOutRedirect];
end;

procedure TProcessDebugger.SetConsoleWinPos(ALeft, ATop: Integer);
begin
  FUseConsoleWinPos := True;
  FConsoleWinPos.X   := ALeft;
  FConsoleWinPos.Y   := ATop;
end;

procedure TProcessDebugger.UnSetConsoleWinPos;
begin
  FUseConsoleWinPos := False;
end;

procedure TProcessDebugger.SetConsoleWinSize(AWidth, AHeight: Integer);
begin
  FUseConsoleWinSize := True;
  FConsoleWinSize.X   := AWidth;
  FConsoleWinSize.Y   := AHeight;
end;

procedure TProcessDebugger.UnSetConsoleWinSize;
begin
  FUseConsoleWinSize := False;
end;

procedure TProcessDebugger.SetConsoleWinBuffer(AColumns, ARows: Integer);
begin
  FUseConsoleWinBuffer := True;
  FConsoleWinBuffer.X   := AColumns;
  FConsoleWinBuffer.Y   := ARows;
end;

procedure TProcessDebugger.UnSetConsoleWinBuffer;
begin
  FUseConsoleWinBuffer := False;
end;

initialization
  RegisterDebugger(TProcessDebugger);

end.
