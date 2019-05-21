
(
--Globals
persistent global path_settings, path_project, editingProject
--Rollouts
global PipeBoy_ProjectSettings
global PipeBoy
global rlt_addProject
global projectsArray
global PBS

--Start script--
fn getScriptLocation =
(
	local ScriptName = "PipeBoy_ProjectSettings.ms"
	local FileName = getThisScriptFilename()  as string
	local FilteredPath = replace FileName (FileName.count - ScriptName.count + 1) (ScriptName.count) ""

	free ScriptName
	free FileName
	
	return FilteredPath
)
--Open script window--

rollout PipeBoy_ProjectSettings "Project Settings" width:300 height:400
(
	group "Project"
	(
		dropdownlist currentProject "" width:125
		button button_addProject "Add" pos:[145,24]
		button button_saveSettings "Save" pos:[185,24]
		button button_removeProject "Remove" pos:[230,24]
	)
	
	group "Project Settings"
	(
		dropdownlist s_Engine "Engine" items:#("Unity", "Unreal Engine 4") width:125
		
		edittext p_projectRoot "Project path:" text:("D:\\Unity\\Your\\ProjectRoot\\") width: 275 align:#left tooltip:"Path to project's root directory"
		edittext p_projectSource "Project Source:" text:("D:\\Unity\\Your\\ProjectSource\\") width: 275 align:#left tooltip:"Path to project's 'source/ raw' directory"
		edittext p_projectAsset "Asset folder:" text:("") width: 275 align:#left tooltip:"Extra path directory for asset folder"
		checkbox s_ImportFromRaw "Import from raw, setup"
	)
	
	group "Geometry"
	(
		edittext s_MeshGroupPrefix "Mesh group prefix:" text:"g_" width: 200 align:#left
		dropdownlist s_ForwardAxis "Axis Forward" items:#("(+) X-Forward", "(-) X-Forward", "(+) Y-Forward", "(-) Y-Forward") width:125
	)
	
	group "Animation"
	(
		edittext s_BonePrefix "Bone prefix:" text:"b_" width: 200 align:#left
		edittext s_AlignPrefix "Align prefix:" text:"align_" width: 200 align:#left
		edittext s_BoneRoot "Root bone name:" text:"b_root" width: 200 align:#left
	)
	
	fn SaveSettings =
	(
		if (queryBox "Overwrite settings?" title:"Save") do
		(
			local pro = (projectsArray[currentProject.selection] as string)
			
			print("Saving settings to file: " +PBS + " as project: " + pro)
			
			--Save global settings
			setINISetting PBS "MainData" "g_Projects" (projectsArray as string)
			
			--Save project specific
			--setINISetting <filename_string> <section_string> <key_string> <key_value_string>
			setINISetting PBS pro "p_projectRoot" (p_projectRoot.text)
			setINISetting PBS pro "p_projectSource" (p_projectSource.text)
			setINISetting PBS pro "p_projectAsset" (p_projectAsset.text)
			
			setINISetting PBS pro "s_Engine" (s_Engine.selection as string)	
			setINISetting PBS pro "s_ImportFromRaw" (s_ImportFromRaw.state as string)	
			setINISetting PBS pro "s_ForwardAxis" (s_ForwardAxis.selection as string)
			setINISetting PBS pro "s_MeshGroupPrefix" (s_MeshGroupPrefix.text)
			
			setINISetting PBS pro "s_BonePrefix" (s_BonePrefix.text)
			setINISetting PBS pro "s_BoneRoot" (s_BoneRoot.text)
			setINISetting PBS pro "s_AlignPrefix" (s_AlignPrefix.text)
		)
	)
	
	fn LoadSettings =
	(
		tempProjectsArray = (getINISetting PBS "MainData" "g_Projects")
		
		if (currentProject.selection == 0 OR currentProject.selection == undefined) then 
		(
			local tempProjectSelection = 1
		)
		else
		(
			local tempProjectSelection = currentProject.selection
		)
			
		if (tempProjectsArray != "") and (tempProjectsArray != undefined) then
		(
			--Safely transfer array into actual variable
			projectsArray = execute tempProjectsArray
			
			--Check if project still exists
			if (projectsArray[tempProjectSelection] != undefined) then
			(		
				currentProject.items = projectsArray
				
				editingProject = tempProjectSelection
				
				local pro = (currentProject.selected as string)
				
				print("Loading settings from file: " + PBS + " as project: " + pro)

				--Load project specific
				p_projectRoot.text = (getINISetting PBS pro "p_projectRoot")
				p_projectSource.text = (getINISetting PBS pro "p_projectSource")
				p_projectAsset.text = (getINISetting PBS pro "p_projectAsset")
				
				
				s_Engine.selection = (getINISetting PBS pro "s_Engine") as Integer
				s_ImportFromRaw.state = (getINISetting PBS pro "s_ImportFromRaw") as booleanClass
				s_ForwardAxis.selection = (getINISetting PBS pro "s_ForwardAxis") as Integer
				s_MeshGroupPrefix.text = (getINISetting PBS pro "s_MeshGroupPrefix")
				
				s_BonePrefix.text = (getINISetting PBS pro "s_BonePrefix")
				s_BoneRoot.text = (getINISetting PBS pro "s_BoneRoot")
				s_AlignPrefix.text = (getINISetting PBS pro "s_AlignPrefix")
			)
			else
			(
				MessageBox "Project seems to be missing" title:"Missing project!"
			)
		)
		else
		(
			messageBox "Project data is missing!" title:"Error"
		)
	)
	
	fn AttemptLoadFile =
	(
		global dirty = false
		
		fn CheckSettingChanged t_setting t_settingKey t_type =
		(
			local pro = (projectsArray[editingProject] as string)
			getSetting = (getINISetting PBS pro (t_settingKey as string)) as t_type
			if (t_setting != getSetting) do (dirty = true)
		)
		
		CheckSettingChanged p_projectRoot.text "p_projectRoot" string
		CheckSettingChanged p_projectSource.text "p_projectSource" string
		CheckSettingChanged p_projectAsset.text "p_projectAsset" string
		
		CheckSettingChanged s_Engine.selection "s_Engine" Integer
		CheckSettingChanged s_ImportFromRaw.state "s_ImportFromRaw" booleanClass
		CheckSettingChanged s_ForwardAxis.selection "s_ForwardAxis" Integer
		CheckSettingChanged s_MeshGroupPrefix.text "s_MeshGroupPrefix" string
		
		CheckSettingChanged s_BonePrefix.text "s_BonePrefix" string
		CheckSettingChanged s_BoneRoot.text "s_BoneRoot" string
		CheckSettingChanged s_AlignPrefix.text "s_AlignPrefix" string
		
		if (dirty == true) then
		(
			if (queryBox "Discard unsaved changes?" title:"Discard" == false) then 
			(
				currentProject.selection = editingProject
			)
			else
			(
				LoadSettings()
			)
		)
		else
		(
			LoadSettings()
		)
	)
	
	on PipeBoy_ProjectSettings open do
	(
		--print ("Doing opening actions!")
		path_settings = getScriptLocation()
		PBS = (path_settings + "Pipeboy_Settings.ini") --Setup settings file

		if (editingProject != undefined or editingProject == 0) then
		(
			currentProject.selection = editingProject
		)
		else
		(
			currentProject.selection = 1
			editingProject = 1
		)
	
		--Load in data
		LoadSettings()
	)

	on button_addProject pressed do
	(
		TempList = projectsArray
		createDialog rlt_addProject
	)
	
	on button_removeProject pressed do
	(
		if (queryBox "Are you sure you want to remove the project? This action is not undoable." title:"Remove project" == true) do
		(
			delIniSetting PBS currentProject.selected
			
			deleteItem projectsArray currentProject.selection
			
			currentProject.items = projectsArray
			currentProject.selection = 1
			editingProject = 1
			
			--Save global settings
			setINISetting PBS "MainData" "g_Projects" (projectsArray as string)
			
			LoadSettings()
		)
	)
	
	on button_saveSettings pressed do
	(	
		SaveSettings()
	)
	
	on currentProject selected undefined do 
	(
		if (currentProject.selection != editingProject) then
		(
			AttemptLoadFile()
		)
	)
)

rollout rlt_addProject "Add project" width:275 height:60
(
	edittext project_name "Project name:" fieldWidth:150 labelOnTop:true
	button okButton "Add" pos:[170,21]
	button cancelButton "Cancel" pos:[210,21]
	
	fn CommitProject =
	(
		if (project_name.text != "") then
		(
			append projectsArray (project_name.text as string)
			PipeBoy_ProjectSettings.currentProject.items = projectsArray
			PipeBoy_ProjectSettings.currentProject.selection = projectsArray.count
			editingProject = projectsArray.count
			
			destroyDialog rlt_addProject
		)
		else
		(
			messageBox "Enter a name" title:"Are you dumb?"
		)
	)
	
	on okButton pressed do
	(
		CommitProject()
	)
	
	on project_name entered newText do
	(
		CommitProject()
	)
	
	on cancelButton pressed do
	(
		destroyDialog rlt_addProject
	)
)

createDialog PipeBoy_ProjectSettings  pos:[1100,500]
--clearListener()
)