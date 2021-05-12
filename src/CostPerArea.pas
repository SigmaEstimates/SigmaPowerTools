unit CostPerArea;

// **************************************************
//  Version: 1.0
//  Date: 2021.05.01
//  Developer: Anole IT (on behalf of Estimating Am.
// **************************************************

interface //-----------------------------------------

uses
  Sigma.Document,
  System.IO,
  System.IO.Inifiles,
  System.UI.Ribbon,
  System.UI.ActionList,
  System.UI.Dialogs,
  CostPerArea.Settings;

const
  CONSTANT_TOTAL_AREA = 'POWERTOOLS_TOTAL_PROJECT_AREA';
  ConstantUOM = 'POWERTOOLS_UOM';
  CUSTOMFIELD_COST_PR_AREA = 'PowerTools_CostPrArea';
  CUSTOMFIELD_SALES_PR_AREA = 'PowerTools_SalesPrArea';

type
  TCostPrArea = class
    private
      sInifile = '%sigma_currentuser%\estimatingamerica\costprarea.settings.ini';
	  
      procedure OpenSettings(Sender: TRibbonItem);
      procedure SetArea(Sender: TRibbonItem);
	  
    public
      constructor Create(ribbonGroup: TRibbonTabGroup);
      destructor Destroy; override;
      procedure AddRibbon;
      procedure LoadSettings;
      procedure SaveSettings;
      procedure Refresh();
      function GetTypeText() : string;
      procedure FullCalculate(Sender: TRibbonItem);
      procedure CalculateChange(item : TSigmaItem);
      procedure SetItemValues(item : TSigmaItem);
      procedure DoOnProjectItemColumnNotify (AProject: TSigmaProject; Action: TSigmaProjectItemColumnNotification; ColumnIndex: Integer);
      procedure DoOnApplicationProjectNotify(AApplication: TSigmaApplication; AProject: TSigmaProject; Notification: TSigmaApplicationProjectNotification);
      FSettings : TCostPrAreaSettings;
      FTotalArea : float;
      FAreaButton : TRibbonLargeButtonItem;
      FRibbonGroup: TRibbonTabGroup;
  end;

implementation //-----------------------------------------

constructor TCostPrArea.Create(ribbonGroup : TRibbonTabGroup);
begin
  FRibbonGroup := ribbonGroup;
  FSettings := TCostPrAreaSettings.Create();
  LoadSettings();
  AddRibbon();
  Refresh();

  // hook up on the project notify, in order to change Total Area on Project change
  Application.OnProjectNotify := DoOnApplicationProjectNotify;
end;

destructor TCostPrArea.Destroy;
begin
end;

procedure TCostPrArea.LoadSettings;
begin
  var IniFile := TMemoryIniFile.Create;
    try
        IniFile.LoadFromFile(sInifile);

        // load settings
        FSettings.UseMetric  := StrToBool(IniFile.ReadString('Settings', 'UseMetric', 'False'));
        FSettings.AutoUpdate := StrToBool(IniFile.ReadString('Settings', 'AutoUpdate', 'True'));
        FSettings.ShowCostColumn := StrToBool(IniFile.ReadString('Settings', 'ShowCostColumn', 'True'));
        FSettings.ShowSalesColumn := StrToBool(IniFile.ReadString('Settings', 'ShowSalesColumn', 'True'));
     except
      on E: Exception do
   begin
     ShowMessage(Format('%s', [E.Message]));
   end;
   finally
     IniFile.Free;
   end;
end;

procedure TCostPrArea.SaveSettings;
begin
   var IniFile := TMemoryIniFile.Create;
    try
        if not FileSystem.FileExists(sIniFile) then
        begin
          Directory.CreateDirectory(Path.GetDirectoryName(FileSystem.ResolveFilename(sIniFile)));
        end;

        IniFile.LoadFromFile(sInifile);
        IniFile.Clear;

        // save settings
        IniFile.WriteString('Settings', 'UseMetric', FSettings.UseMetric.ToString());
	IniFile.WriteString('Settings', 'AutoUpdate', FSettings.AutoUpdate.ToString());
        IniFile.WriteString('Settings', 'ShowCostColumn', FSettings.ShowCostColumn.ToString());
        IniFile.WriteString('Settings', 'ShowSalesColumn', FSettings.ShowSalesColumn.ToString());

        IniFile.SaveToFile(sInifile);
     except
      on E: Exception do
      begin          
          ShowMessage(Format('%s', [E.Message]));
	  end;
    finally
        IniFile.Free;
    end;

end;

procedure TCostPrArea.OpenSettings(Sender: TRibbonItem);
begin
  var Form := TCostPrAreaSettingsForm.Create(FSettings);
  try
    if Form.ShowModal = mrOK then
    begin
        FSettings := Form.FSettings;
        SaveSettings;
        Refresh;
    end;

  except
    on E: Exception do
      begin        
        ShowMessage(Format('%s', [E.Message]));
      end;
  finally
    Form.Free;
  end;
end;

procedure TCostPrArea.SetArea(Sender: TRibbonItem);
begin

  try
     var Project = Application.ActiveProject;

     if Project = nil then
       exit;

     var s: string;
     s := FloatToStr(Project.Symbols.Values[CONSTANT_TOTAL_AREA]);
     if InputQuery(_('Total area'), _('Please enter total project area'), s) then
     begin
       Project.Symbols.Values[CONSTANT_TOTAL_AREA] := StrToFloatDef(s, 0);
       Refresh();
     end
     else
     begin
       ShowMessage(_('Invalid input - please enter a valid number'));
       exit;
     end;
  except
    on E: Exception do
      begin        
        ShowMessage(Format('%s', [E.Message]));
      end;
  end;
end;

procedure TCostPrArea.AddRibbon;
begin  
  if FRibbonGroup = nil then
     exit;

  FAreaButton := FRibbonGroup.Items.Add(TRibbonLargeButtonItem) as TRibbonLargeButtonItem;
  FAreaButton.ButtonStyle := rbsDropDown;
  FAreaButton.LargeGlyph.LoadFromFile('icons\costprarea.png', true);
  var Action = Application.Actions.Add;
  FAreaButton.Action := Action;
  Action.OnUpdate := procedure(A: TAction) begin
       A.Enabled := Application.ActiveProject <> nil;
  end;

  var subItem := FAreaButton.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Set area');
  subItem.Glyph.LoadFromFile('icons\editarea.png', true);
  subItem.OnClick := SetArea;

  subItem := FAreaButton.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Recalculate project');
  subItem.Glyph.LoadFromFile('icons\calc_costprarea.png', true);
  subItem.OnClick := FullCalculate;

  subItem := FAreaButton.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Settings');
  subItem.Glyph.LoadFromFile('icons\gear.png', true);
  subItem.OnClick := OpenSettings;
end;

procedure TCostPrArea.Refresh;
begin
  var area := 0;

  if Application.ActiveProject <> nil then
  begin
    var Project := Application.ActiveProject;

    if FSettings.AutoUpdate then
    begin
      Project.OnItemColumnNotify := DoOnProjectItemColumnNotify;
    end
    else
    begin
      Project.OnItemColumnNotify := nil;
    end;

    var costCF := Project.CustomFields.AddOrUpdate(CUSTOMFIELD_COST_PR_AREA, _('Cost/') + GetTypeText(), _('Calculated cost per ') + GetTypeText());
    costCF.FieldType := cfTypeFloat;
    costCF.Precision := 2;
    costCF.DisplayThousandSeparator := true;

    var salesCF := Project.CustomFields.AddOrUpdate(CUSTOMFIELD_SALES_PR_AREA, _('Sales/') + GetTypeText(), _('Calculated sales per ') + GetTypeText());
    salesCF.FieldType := cfTypeFloat;
    salesCF.Precision := 2;
    salesCF.DisplayThousandSeparator := true;

    if FSettings.ShowCostColumn then
      Project.Pages.FindPageByID('sigma.project.content').Columns.CustomFieldColumns[CUSTOMFIELD_COST_PR_AREA].Visible := true
    else
      Project.Pages.FindPageByID('sigma.project.content').Columns.CustomFieldColumns[CUSTOMFIELD_COST_PR_AREA].Visible := false;

    if FSettings.ShowSalesColumn then
      Project.Pages.FindPageByID('sigma.project.content').Columns.CustomFieldColumns[CUSTOMFIELD_SALES_PR_AREA].Visible := true
    else
      Project.Pages.FindPageByID('sigma.project.content').Columns.CustomFieldColumns[CUSTOMFIELD_SALES_PR_AREA].Visible := false;

    area := Project.Symbols.Values[CONSTANT_TOTAL_AREA];

    if Project.Modified then
      Project.Update;
  end;

  FTotalArea := area;
  FAreaButton.Caption := _('Area: ') + area.ToString() + ' ' + GetTypeText();
end;

procedure TCostPrArea.FullCalculate(Sender: TRibbonItem);
begin
  var Project := Application.ActiveProject;
  
  if Project = nil then
    exit;

  if (not Project.Symbols.Contains(CONSTANT_TOTAL_AREA)) or (FTotalArea = 0) then
  begin
     SetArea(nil);
  end;

  var Queue: array of TSigmaITem;

  Project.BeginUpdate();

  Queue.Add( Project.RootItem );
  while (Queue.Count > 0) do
  begin
    var item := Queue.Pop;
    SetItemValues(item);
    for var i := 0 to item.Items.Count-1 do
      Queue.Insert( 0, item.Items[i] );
  end;

  Project.EndUpdate();
  Project.Update();
end;

procedure TCostPrArea.CalculateChange(item : TSigmaItem)
begin

  if (FTotalArea > 0) and (Application.ActiveProject <> nil) then
  begin
    SetItemValues(item);

    if item.Parent <> nil then
    begin
      CalculateChange(item.Parent);
    end;

    Application.ActiveProject.Update();
  end;
end;

procedure TCostPrArea.SetItemValues(item : TSigmaItem)
begin
  item.CustomFieldValues[CUSTOMFIELD_COST_PR_AREA] := item.Values[tcAbsoluteRegCostPrice] / FTotalArea;
  item.CustomFieldValues[CUSTOMFIELD_SALES_PR_AREA] := item.Values[tcAbsoluteSalesPrice] / FTotalArea;
end;

function TCostPrArea.GetTypeText() : string;
begin
   if FSettings.UseMetric then
   begin
     Result := 'm2';
   end
   else
   begin
     Result := 'SF';
   end;
end;

procedure TCostPrArea.DoOnProjectItemColumnNotify (AProject: TSigmaProject; Action: TSigmaProjectItemColumnNotification; ColumnIndex: Integer);
begin
  case Action of
    picEdited:
     CalculateChange(AProject.ActiveItem);
  end;
end;

procedure TCostPrArea.DoOnApplicationProjectNotify(AApplication: TSigmaApplication; AProject: TSigmaProject; Notification: TSigmaApplicationProjectNotification);
begin
  case Notification of
    apnActivate:
      Refresh();
  end;
end;

initialization //-----------------------------------------

finalization //-----------------------------------------
