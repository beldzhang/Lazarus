{***************************************************************************
 *                                                                         *
 * This unit is distributed under the LGPL version 2                       *
 *                                                                         *
 * Additionally this unit can be used under any newer version (3 or up)    *
 * of the LGPL                                                             *
 *                                                                         *
 * Users are also granted the same "linknig exception" as defined          *
 * for the LCL.                                                            *
 * See the LCL license for details                                         *
 *                                                                         *
 *                                                                         *
 ***************************************************************************
 @author(Martin Friebe)
}
unit LazDebuggerIntf;

{$mode objfpc}{$H+}
{$INTERFACES CORBA} // no ref counting needed

interface

uses
  Classes, SysUtils;

type

  { Debugger states
    --------------------------------------------------------------------------
    dsNone:
      The debug object is created, but no instance of an external debugger
      exists.
      Initial state, leave with Init, enter with Done

    dsIdle:
      The external debugger is started, but no filename (or no other params
      required to start) were given.

    dsStop:
      (Optional) The execution of the target is stopped
      The external debugger is loaded and ready to (re)start the execution
      of the target.
      Breakpoints, watches etc can be defined

    dsPause:
      The debugger has paused the target. Target variables can be examined

    dsInternalPause:
      Pause, not visible to user.
      For examble auto continue breakpoint: Allow collection of Snapshot data

    dsInit:
      (Optional, Internal) The debugger is about to run

    dsRun:
      The target is running.

    dsError:
      Something unforseen has happened. A shutdown of the debugger is in
      most cases needed.

    -dsDestroying
      The debugger is about to be destroyed.
      Should normally happen immediate on calling Release.
      But the debugger may be in nested calls, and has to exit them first.
    --------------------------------------------------------------------------
  }
  TDBGState = (
    dsNone,
    dsIdle,
    dsStop,
    dsPause,
    dsInternalPause,
    dsInit,
    dsRun,
    dsError,
    dsDestroying
    );

  {$REGION ***** Internal types ***** }

  TInternalDbgMonitorIntfType  = interface end;
  TInternalDbgSupplierIntfType = interface end;

  generic TInternalDbgMonitorIntf<_SUPPLIER_INTF> = interface(TInternalDbgMonitorIntfType)
    function GetSupplier: _SUPPLIER_INTF;
    procedure SetSupplier(ASupplier: _SUPPLIER_INTF);

    procedure DoStateChange(const AOldState, ANewState: TDBGState);

    property Supplier: _SUPPLIER_INTF read GetSupplier write SetSupplier;
  end;

  generic TInternalDbgSupplierIntf<_MONITOR_INTF> = interface(TInternalDbgSupplierIntfType)
    procedure SetMonitor(AMonitor: _MONITOR_INTF);

    procedure DoStateChange(const AOldState: TDBGState);
  end;

  {$ENDREGION}

type

  TDebuggerDataState = (ddsUnknown,                    //
                        ddsRequested, ddsEvaluating,   //
                        ddsValid,                      // Got a valid value
                        ddsInvalid,                    // Does not have a value
                        ddsError                       // Error, but got some Value to display (e.g. error msg)
                       );

  TDbgDataRequestIntf = interface
    procedure AddFreeNotification(ANotification: TNotifyEvent);
    procedure RemoveFreeNotification(ANotification: TNotifyEvent);
  end;



{%region **********************************************************************
 ******************************************************************************
 **                                                                          **
 **   W A T C H T E S                                                        **
 **                                                                          **
 ******************************************************************************
 ******************************************************************************}

  TWatchDisplayFormat =
    (wdfDefault,
     wdfStructure,
     wdfChar, wdfString,
     wdfDecimal, wdfUnsigned, wdfFloat, wdfHex,
     wdfPointer,
     wdfMemDump, wdfBinary
    );

  TWatcheEvaluateFlag =
    (defNoTypeInfo,        // No Typeinfo object will be returned // for structures that means a printed value will be returned
     defSimpleTypeInfo,    // Returns: Kind (skSimple, skClass, ..); TypeName (but does make no attempt to avoid an alias)
     defFullTypeInfo,      // Get all typeinfo, resolve all anchestors
     defClassAutoCast,     // Find real class of instance, and use, instead of declared class of variable
     defAllowFunctionCall//,
//     defRawMemory,         // returns Array of bytes for hex dump
//     defNoValue            // Skip the value, if returning raw mem
    );
  TWatcheEvaluateFlags = set of TWatcheEvaluateFlag;

  TWatcheEvaluateEvent = (
    weeCancel
  );

  TDBGTypeBase = class(TObject)
  end;



  TNumValueFlag = (
    nvfUnsigned,
    //nvfUnknownSize,  // same as size = 0
    nvfAddrType     // default to hex display (Pointer)
  );
  TNumValueFlags = set of TNumValueFlag;

  { TWatchValueIntf }

  TWatchValueIntf = interface(TDbgDataRequestIntf)
    (* Begin/EndUdate
       - shall indicate that the newly set values are now valid. Ready for display.
         (Indicated by EndUpdate)
       - shall protect the object from destruction.
         A debugger backend may access the object during this time, without further checks.
       - shall ensure changes outside the backend, will not affect calls by the
         backend to any method setting/adding/modifing requested data.
         ~ I.e. if the backend adds values to an array or structure, further calls
           by the backend to add more data must be accepted without failure.
         ~ However, further data may be discarded internally, if possible without
           causing later failures (e.g. if the requested data is no longer needed)
   (!) - does NOT affect, if read-only properties/functions can change their value.
         E.g., if the requested value is no longer needed, then "Expression" and
         other "passed in/provided values" may change (reset to default/empty)
     * When used in the IDE (Begin/EndUpdate themself shall only be valid in the main thread),
       shall
       - allow the backend to read "passed in/provided values" from another thread
       - allow the backend to set new values from another thread
         (I.e., if the IDE (or any non-backend code) makes changes, they must
          consider thread safety)
       // Any "frontend" outside the IDE (commandline / dbg-server) doens not
          need to consider thread safety, as long as it knows that this in not
          required by any of the backends it uses.
    *)
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure AddNotification(AnEventType: TWatcheEvaluateEvent; AnEvent: TNotifyEvent);
    procedure RemoveNotification(AnEventType: TWatcheEvaluateEvent; AnEvent: TNotifyEvent);

    procedure SetNumValue(ANumValue: QWord; AByteSize: Integer = 0; AFlags: TNumValueFlags = []);
    procedure SetTypeName(ATypeName: String);

    function GetDisplayFormat: TWatchDisplayFormat;
    function GetEvaluateFlags: TWatcheEvaluateFlags;
    function GetExpression: String;
    function GetRepeatCount: Integer;
    function GetStackFrame: Integer;
    function GetThreadId: Integer;
    function GetValidity: TDebuggerDataState;
    procedure SetTypeInfo(AValue: TDBGTypeBase);
    function GetValue: String; // FpGdbmiDebugger
    procedure SetValidity(AValue: TDebuggerDataState);
    procedure SetValue(AValue: String);

    property DisplayFormat: TWatchDisplayFormat read GetDisplayFormat;
    property EvaluateFlags: TWatcheEvaluateFlags read GetEvaluateFlags;
    property RepeatCount: Integer read GetRepeatCount;
    property ThreadId: Integer read GetThreadId;
    property StackFrame: Integer read GetStackFrame;
    property Expression: String read GetExpression;

    property Validity: TDebuggerDataState read GetValidity write SetValidity;
    property Value: String read GetValue write SetValue;
    property TypeInfo: TDBGTypeBase {read GetTypeInfo} write SetTypeInfo;
  end;



  TWatchesSupplierIntf = interface;

  TWatchesMonitorIntf  = interface(specialize TInternalDbgMonitorIntf<TWatchesSupplierIntf>)
    procedure InvalidateWatchValues;
  end;

  TWatchesSupplierIntf = interface(specialize TInternalDbgSupplierIntf<TWatchesMonitorIntf>)
    procedure RequestData(AWatchValue: TWatchValueIntf);
    procedure TriggerInvalidateWatchValues;
  end;

{%endregion   ^^^^^  Watches  ^^^^^   }



implementation


end.
