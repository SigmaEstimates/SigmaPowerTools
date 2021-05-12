unit CostPerArea.Settings;

{.$define TEST}

interface

uses
  System.UI.ActionList,
  System.UI.Dialogs,
  System.UI.Controls,
  System.UI.ListView,
  System.UI.Layout,
  System.Help,
  System.IO;

// -----------------------------------------------------------------------------
//
// TCostPrAreaSettingsForm
//
// -----------------------------------------------------------------------------
type
  TCostPrAreaSettings = class
      UseMetric : boolean; // True if m2 is to be the label, SF otherwise
      AutoUpdate : boolean; // Will update CostPrArea on itemChange, if true
      ShowCostColumn : boolean;
      ShowSalesColumn : boolean;
   public
      procedure Assign(sourceSettings : TCostPrAreaSettings);
  end;

  TCostPrAreaSettingsForm = class(TDialog)
  private
    FLayout: TLayout;
    FActionList: TActionList;
    FLayoutHeaderStyle: TLayoutStyle;
    FLayoutInfoStyle: TLayoutStyle;

    FCheckBoxMetric : TCheckBox;
    FCheckBoxUS : TCheckBox;
    FCheckBoxAutoUpdate : TCheckBox;
    FCheckBoxShowCostColumn : TCheckBox;
    FCheckBoxShowSalesColumn : TCheckBox;
    

  protected
    procedure OnActionOKExecute(Sender: TAction);
    procedure OnAfterShowHandler(Sender: TControl);
    procedure OnFCheckBoxUSCheckChanged(Sender: TControl);
    procedure OnFCheckBoxMetricCheckChanged(Sender: TControl);

    procedure Initialize;
    procedure Refresh;
  public    
    constructor Create(settings: TCostPrAreaSettings);
    destructor Destroy; override;

    function Execute: boolean;

    FSettings : TCostPrAreaSettings;

  end;

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

implementation

// -----------------------------------------------------------------------------

procedure TCostPrAreaSettings.Assign(sourceSettings : TCostPrAreaSettings);
begin
  UseMetric := sourceSettings.UseMetric;
  AutoUpdate := sourceSettings.AutoUpdate;
  ShowCostColumn := sourceSettings.ShowCostColumn;
  ShowSalesColumn := sourceSettings.ShowSalesColumn;
end;

constructor TCostPrAreaSettingsForm.Create(settings: TCostPrAreaSettings);
begin
  inherited Create;

  Initialize;
  FSettings := settings;
  
  Refresh;
end;

destructor TCostPrAreaSettingsForm.Destroy;
begin
  inherited;
end;

// -----------------------------------------------------------------------------

procedure TCostPrAreaSettingsForm.Initialize;
begin
  Caption := _('Settings');
  //Title := _('settings_description');
  //MinorTitle := TAppInfo.Version;

  Width := 550;
  //Height := 500;

  //ActionOK.OnUpdate := OnActionOKUpdate;
  ActionOK.OnExecute := OnActionOKExecute;
  //OnAfterShow := OnAfterShowHandler;

  FActionList := TActionList.Create(nil);

  FLayoutInfoStyle := TLayoutStyle.Create;
  FLayoutInfoStyle.ItemOptions.CaptionOptions.TextColor := $FF9933;

  FLayoutHeaderStyle := TLayoutStyle.Create;
  FLayoutHeaderStyle.ItemOptions.CaptionOptions.Font.Style := [fsBold];

  FLayout := TLayout.Create(Self);
  FLayout.Parent := Container;
  FLayout.ParentBackground := True;
  FLayout.Align := alClient;
  FLayout.Items.AlignHorz := ahClient;
  FLayout.Items.AlignVert := avClient;
  FLayout.DefaultStyle.Offsets.RootItemsAreaOffsetHorz := 0;
  FLayout.DefaultStyle.Offsets.RootItemsAreaOffsetVert := 0;

  // main group container
  /*var Group := FLayout.Items.CreateGroup;
  Group.Caption.AlignHorz := taLeftJustify;
  Group.AlignVert := avClient;
  Group.LayoutDirection := ldTabbed;
  Group.ShowBorder := false;
    */

  // Settings
  var GroupSettings := FLayout.Items.CreateGroup;
  GroupSettings.Caption.AlignHorz := taLeftJustify;
  GroupSettings.AlignVert := avClient;
  GroupSettings.LayoutDirection := ldVertical;
  GroupSettings.ShowBorder := false;
  //GroupSettings.Caption.Text := _('settings');
  //GroupSettings.Visible := false;

  var GroupAreaType := GroupSettings.CreateGroup;
  GroupAreaType.Caption.Text := _('Choose area display');
  //GroupAreaType.Style.GroupOptions.Color := GroupSettings.Style.GroupOptions.Color;

  FCheckBoxUS := TCheckBox.Create(Self);
  FCheckBoxUS.Caption := _('SF');
  //FCheckBoxAutoUpdate.Hint := _('removeContentControls_hint');
  FCheckBoxUS.OnClick := OnFCheckBoxUSCheckChanged;
  GroupAreaType.CreateItem(FCheckBoxUS);

  FCheckBoxMetric := TCheckBox.Create(Self);
  FCheckBoxMetric.Caption := _('m2');
  FCheckBoxMetric.OnClick := OnFCheckBoxMetricCheckChanged;
  //FCheckBoxAutoUpdate.Hint := _('removeContentControls_hint');
  GroupAreaType.CreateItem(FCheckBoxMetric);

  var GroupShow := GroupSettings.CreateGroup;

  FCheckBoxAutoUpdate := TCheckBox.Create(Self);
  FCheckBoxAutoUpdate.Caption := _('Auto update when item price is changed');
  //FCheckBoxAutoUpdate.Hint := _('removeContentControls_hint');
  GroupShow.CreateItem(FCheckBoxAutoUpdate);

  FCheckBoxShowCostColumn := TCheckBox.Create(Self);
  FCheckBoxShowCostColumn.Caption := _('Show cost column in Content sheet');
  //FCheckBoxAutoUpdate.Hint := _('removeContentControls_hint');
  GroupShow.CreateItem(FCheckBoxShowCostColumn);

  FCheckBoxShowSalesColumn := TCheckBox.Create(Self);
  FCheckBoxShowSalesColumn.Caption := _('Show sales column in Content sheet');
  //FCheckBoxAutoUpdate.Hint := _('removeContentControls_hint');
  GroupShow.CreateItem(FCheckBoxShowSalesColumn);


  // add version
  //var lblVersion := TLabel.Create(Self);
  //lblVersion.Text := _('ver: ') + TAppInfo.Version;
  //lblVersion.Align := alBottom;
  //FLayout.Items.CreateItem(lblVersion);

end;

// -----------------------------------------------------------------------------

procedure TCostPrAreaSettingsForm.OnAfterShowHandler(Sender: TControl);
begin
  Update;
  try
  except
    ModalResult := TModalResult.mrCancel;
    raise;
  end;
end;

// -----------------------------------------------------------------------------

procedure TCostPrAreaSettingsForm.OnActionOKExecute(Sender: TAction);
begin
    FSettings.UseMetric := FCheckBoxMetric.Checked;
    FSettings.AutoUpdate := FCheckBoxAutoUpdate.Checked;
    FSettings.ShowCostColumn := FCheckBoxShowCostColumn.Checked;
    FSettings.ShowSalesColumn := FCheckBoxShowSalesColumn.Checked;
end;

// -----------------------------------------------------------------------------

procedure TCostPrAreaSettingsForm.Refresh;
begin

  FCheckBoxMetric.Checked := FSettings.UseMetric;
  FCheckBoxUS.Checked := not FSettings.UseMetric;
  FCheckBoxAutoUpdate.Checked := FSettings.AutoUpdate;
  FCheckBoxShowCostColumn.Checked := FSettings.ShowCostColumn;
  FCheckBoxShowSalesColumn.Checked := FSettings.ShowSalesColumn;
  
end;

procedure TCostPrAreaSettingsForm.OnFCheckBoxUSCheckChanged(Sender: TControl);
begin
  var ctrl := Sender as TCheckBox;
  if ctrl.Checked then
    FCheckBoxMetric.Checked := not ctrl.Checked;
end;

procedure TCostPrAreaSettingsForm.OnFCheckBoxMetricCheckChanged(Sender: TControl);
begin
  var ctrl := Sender as TCheckBox;
  if ctrl.Checked then
    FCheckBoxUS.Checked := not ctrl.Checked;
end;
// -----------------------------------------------------------------------------

function TCostPrAreaSettingsForm.Execute: boolean;
begin
  try
    Result := inherited Execute;
  except
    on E: Exception do
      ShowMessage(Format('%s', [E.Message]));
  end;
end;

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------


initialization

finalization
end;