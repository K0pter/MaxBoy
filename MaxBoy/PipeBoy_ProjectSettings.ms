/*////////////////////////////////////////////////
PipeBoy_ProjectSettings is used to set up projects
for the main PipeBoy tool.
////////////////////////////////////////////////*/

(
--include "MaxBoy_Functions.ms"
--include "$userScripts\MaxBoy\MaxBoy_Functions.ms"

--Rollouts
global rlt_projectSettings_addProject
global UpdateUI

--Update projects array
fn UpdateProjects =
(
	local confirmedProjects = #()

	for pia in TMP_ProjectArray do
	(
		if (hasINISetting PBS pia == true) then
		(
			append confirmedProjects pia
			--print("Found project: " + pia)
		)
		else
		(
			GP_CurrentProjectSelected = 1
			--print("Expected project: '" + pia + "' is missing. Updating project array...")
		)
	)

	if (confirmedProjects.count == 0) do (messageBox "No projects! Add one!" title:"Error: No projects")

	--Update projects array to [Actual] projects in file
	TMP_ProjectArray = confirmedProjects
)

--Save to ini file
fn SaveProjectSettings query: =
(
	fn doSave =
	(
		local cp = GP_CurrentProjectSelected --Current project index
		local pro = (TMP_ProjectArray[cp] as string)

		print("Saving settings to file: " + PBS + " as project: " + pro)

		--Save global settings
		setINISetting PBS "MainData" "g_Projects" (TMP_ProjectArray as string)

		--Save project specific
		--setINISetting <filename_string> <section_string> <key_string> <key_value_string>
		setINISetting PBS pro "p_projectRoot" 			(LS.p_projectRoot)
		setINISetting PBS pro "p_projectSource" 		(LS.p_projectSource)
		setINISetting PBS pro "p_projectAsset" 			(LS.p_projectAsset)

		setINISetting PBS pro "s_Engine" 				(LS.s_Engine as string)
		setINISetting PBS pro "s_ImportFromRaw" 		(LS.s_ImportFromRaw as string)
		setINISetting PBS pro "s_ForwardAxis" 			(LS.s_ForwardAxis as string)
		setINISetting PBS pro "s_PreferredPrefixes" 	(LS.s_PreferredPrefixes)
		setINISetting PBS pro "s_MeshGroupPrefix" 		(LS.s_MeshGroupPrefix)

		setINISetting PBS pro "s_BonePrefix" 			(LS.s_BonePrefix)
		setINISetting PBS pro "s_BoneRoot" 				(LS.s_BoneRoot)
		setINISetting PBS pro "s_AlignPrefix" 			(LS.s_AlignPrefix)

		setINISetting PBS pro "s_ac_Folder" 			(LS.s_ac_Folder)
		setINISetting PBS pro "s_ac_Prefix" 			(LS.s_ac_Prefix)
		setINISetting PBS pro "s_ac_FindIntelligent"	(LS.s_ac_FindIntelligent as string)
		setINISetting PBS pro "s_ac_LockRoot" 			(LS.s_ac_LockRoot as string)
		setINISetting PBS pro "s_ac_LockRootDepth" 		(LS.s_ac_LockRootDepth as string)

		setINISetting PBS pro "s_ac_FilePrefix" 		(LS.s_ac_FilePrefix)
		setINISetting PBS pro "s_ac_FileSuffix" 		(LS.s_ac_FileSuffix)
		setINISetting PBS pro "s_ac_RemoveFilePre" 		(LS.s_ac_RemoveFilePre as string)
		setINISetting PBS pro "s_ac_RemoveFileSuf" 		(LS.s_ac_RemoveFileSuf as string)


	)

	if (query == unsupplied) do (query = true)

	if (query == true) then
	(
		if (queryBox "Overwrite settings?" title:"Save") do (doSave())
	)
	else
	(
		doSave()
	)
)

--Load from ini file
fn LoadProjectSettings =
(
	local tArray = (getINISetting PBS "MainData" "g_Projects")

	local selProj = GP_CurrentProjectSelected --Current project index
	if (selProj == 0 or selProj == undefined) do (selProj = 1)

	if ((tArray != "") and (tArray != undefined)) then
	(
		--Safely transfer array into variable
		TMP_ProjectArray = execute tArray

		--Check if project still exists
		if (TMP_ProjectArray[selProj] != undefined) then
		(
			--ui_currentProject.items = TMP_ProjectArray
			local pro = (TMP_ProjectArray[selProj] as string)

			print("Loading settings from file: " + PBS + " as project: " + pro)

			--Load project specific
			LS.p_projectRoot 	 	= (getINISetting PBS pro "p_projectRoot")
			LS.p_projectSource 	 	= (getINISetting PBS pro "p_projectSource")
			LS.p_projectAsset 	 	= (getINISetting PBS pro "p_projectAsset")

			LS.s_Engine 		 	= (getINISetting PBS pro "s_Engine") as Integer
			LS.s_ImportFromRaw 	 	= (getINISetting PBS pro "s_ImportFromRaw") as booleanClass
			LS.s_ForwardAxis 	 	= (getINISetting PBS pro "s_ForwardAxis") as Integer
			LS.s_PreferredPrefixes  = (getINISetting PBS pro "s_PreferredPrefixes")
			LS.s_MeshGroupPrefix 	= (getINISetting PBS pro "s_MeshGroupPrefix")

			LS.s_BonePrefix 	 	= (getINISetting PBS pro "s_BonePrefix")
			LS.s_BoneRoot		 	= (getINISetting PBS pro "s_BoneRoot")
			LS.s_AlignPrefix 	 	= (getINISetting PBS pro "s_AlignPrefix")

			LS.s_ac_Folder 			= (getINISetting PBS pro "s_ac_Folder")
			LS.s_ac_Prefix 			= (getINISetting PBS pro "s_ac_Prefix")
			LS.s_ac_FindIntelligent = (getINISetting PBS pro "s_ac_FindIntelligent") as booleanClass
			LS.s_ac_LockRoot		= (getINISetting PBS pro "s_ac_LockRoot") as booleanClass
			LS.s_ac_LockRootDepth	= (getINISetting PBS pro "s_ac_LockRootDepth") as Integer

			LS.s_ac_FilePrefix 		= (getINISetting PBS pro "s_ac_FilePrefix")
			LS.s_ac_FileSuffix 		= (getINISetting PBS pro "s_ac_FileSuffix")
			LS.s_ac_RemoveFilePre 	= (getINISetting PBS pro "s_ac_RemoveFilePre") as Integer
			LS.s_ac_RemoveFileSuf 	= (getINISetting PBS pro "s_ac_RemoveFileSuf") as Integer

			GP_CurrentProjectSelected = selProj
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

--Main UI window--
rollout PipeBoy_ProjectSettings "Project Settings" width:300 height:430
(
	group "Project"
	(
		dropdownlist ui_currentProject "" width:125
		button ui_button_addProject "Add" pos:[145,24]
		button ui_button_saveSettings "Save" pos:[185,24]
		button ui_button_removeProject "Remove" pos:[230,24]
	)

	group "Project Settings"
	(
		dropdownlist ui_Engine "Engine" items:#("Unity", "Unreal Engine 4") width:125

		edittext ui_projectRoot "Project path:" text:("D:\\Unity\\Your\\ProjectRoot\\") width: 275 align:#left tooltip:"Path to project's root directory"
		edittext ui_projectSource "Project Source:" text:("D:\\Unity\\Your\\ProjectSource\\") width: 275 align:#left tooltip:"Path to project's 'source/ raw' directory"
		--edittext ui_projectAsset "Asset folder:" text:("") width: 275 align:#left tooltip:"Extra path directory for asset folder"
		checkbox ui_ImportFromRaw "Import from source setup" tooltip:"Whether or not to export to external source location or to mirrored project folder."
		edittext ui_preferredPrefixes "Preferred prefixes:" text:("sk:,rig:,fpp:,player:,char:,human:,skeleton:,bones:,a:") width: 275 align:#left tooltip:"Assign a set of prefixes the 'smart algorithms' uses (Seperate by comma)"
	)

	group "Geometry"
	(
		edittext ui_MeshGroupPrefix "Mesh group prefix:" text:"g_" width: 200 align:#left
		--dropdownlist ui_ForwardAxis "Axis Forward" items:#("(+) X-Forward", "(-) X-Forward", "(+) Y-Forward", "(-) Y-Forward") width:125
	)

	/*
	group "Animation"
	(
		edittext ui_BonePrefix "Bone prefix:" text:"b_" width: 200 align:#left
		edittext ui_AlignPrefix "Align prefix:" text:"align_" width: 200 align:#left
		edittext ui_BoneRoot "Root bone name:" text:"b_root" width: 200 align:#left
	)
	*/

	group "Accessory"
	(
		edittext ui_ac_folder "Accessory folder:" text:"WPN" width: 200 align:#left
		--edittext ui_ac_prefix "Accessory prefix:" text:"WPN_" width: 200 align:#left
		--checkbox ui_ac_findIntelligent "Locate accessory intelligently" checked:true tooltip:"Locate accesory based on a set of naming conventions"
		checkbox ui_ac_lockRoot "Zero accessory root" tooltip:"Locks accessory root bone to origo when exporting animation"
		spinner ui_ac_lockRootDepth "Zero hierarchy depth: " type:#integer align:#left width: 75 range:[0, 100, 2] tooltip:"How deep zeroing goes in hierarchy"

		edittext ui_ac_filePrefix "File name prefix:" text:"FPP_WPN_" width: 200 align:#left
		edittext ui_ac_fileSuffix "File name suffix:" text:"" width: 200 align:#left
		spinner ui_ac_removeFilePre "Remove chars pre: " type:#integer align:#left width: 75 range:[0, 100, 8]
		spinner ui_ac_removeFileSuf "Remove chars suf: " type:#integer align:#left width: 75 range:[0, 100, 0]
	)

	--Updates UI fields with file data
	fn UpdateUI =
	(
		ui_currentProject.items 	= TMP_ProjectArray
		ui_currentProject.selection = GP_CurrentProjectSelected

		ui_Engine.selection 	 	= LS.s_Engine
		ui_projectRoot.text 	 	= LS.p_projectRoot
		ui_projectSource.text 	 	= LS.p_projectSource
		--ui_projectAsset.text 	 	= LS.p_projectAsset
		ui_ImportFromRaw.state 	 	= LS.s_ImportFromRaw
		ui_preferredPrefixes.text  	= LS.s_preferredPrefixes

		ui_MeshGroupPrefix.text  	= LS.s_MeshGroupPrefix
		--ui_ForwardAxis.selection 	= LS.s_ForwardAxis

		--ui_BonePrefix.text 		= LS.s_BonePrefix
		--ui_BoneRoot.text 		 	= LS.s_BoneRoot
		--ui_AlignPrefix.text 	 	= LS.s_AlignPrefix

		ui_ac_folder.text 			= LS.s_ac_Folder
		--ui_ac_prefix.text 		 	= LS.s_ac_Prefix
		--ui_ac_findIntelligent.state	= LS.s_ac_FindIntelligent
		ui_ac_lockRoot.state 	 	= LS.s_ac_LockRoot
		ui_ac_lockRootDepth.value 	= LS.s_ac_LockRootDepth

		ui_ac_filePrefix.text 		= LS.s_ac_FilePrefix
		ui_ac_fileSuffix.text 		= LS.s_ac_FileSuffix
		ui_ac_removeFilePre.value 	= LS.s_ac_RemoveFilePre
		ui_ac_removeFileSuf.value 	= LS.s_ac_RemoveFileSuf
	)

	--Perform dirty check before loading new project
	fn CheckIfDirty =
	(
		global dirty = false --Global due to function access
		--Update projects array
		UpdateProjects()

		fn fChanged t_setting t_settingKey t_type =
		(
			local pro = (TMP_ProjectArray[GP_CurrentProjectSelected] as string)
			getSetting = (getINISetting PBS pro (t_settingKey as string)) as t_type
			if (t_setting != getSetting) do (dirty = true)
		)

		--Go through and check all settings in comparison to saved settings
		fChanged ui_projectRoot.text 	  	"p_projectRoot" string
		fChanged ui_projectSource.text    	"p_projectSource" string
		--fChanged ui_projectAsset.text     "p_projectAsset" string

		fChanged ui_Engine.selection 	  	"s_Engine" Integer
		fChanged ui_ImportFromRaw.state   	"s_ImportFromRaw" booleanClass
		fChanged ui_preferredPrefixes.text  "s_PreferredPrefixes" string

		--fChanged ui_ForwardAxis.selection "s_ForwardAxis" Integer
		fChanged ui_MeshGroupPrefix.text  	"s_MeshGroupPrefix" string

		--fChanged ui_BonePrefix.text 	  	"s_BonePrefix" string
		--fChanged ui_BoneRoot.text 		  	"s_BoneRoot" string
		--fChanged ui_AlignPrefix.text 	  	"s_AlignPrefix" string

		fChanged ui_ac_folder.text 	  		"s_ac_Folder" string
		--fChanged ui_ac_prefix.text 	  		"s_ac_Prefix" string
		--fChanged ui_ac_findIntelligent.state "s_ac_FindIntelligent" booleanClass
		fChanged ui_ac_lockRoot.state 	  	 "s_ac_LockRoot" BooleanClass
		fChanged ui_ac_lockRootDepth.value 	 "s_ac_LockRootDepth" Integer

		fChanged ui_ac_filePrefix.text 	  	"s_ac_FilePrefix" string
		fChanged ui_ac_fileSuffix.text 		"s_ac_FileSuffix" string
		fChanged ui_ac_removeFilePre.value 	"s_ac_RemoveFilePre" Integer
		fChanged ui_ac_removeFileSuf.value 	"s_ac_RemoveFileSuf" Integer

		return dirty
	)

	fn TrySetNewProject newProject =
	(
		if (newProject == GP_CurrentProjectSelected) do (return())

		local pro = GP_CurrentProjectSelected
		local dirty = CheckIfDirty()

		if (dirty == true) do
		(
			if (queryBox "Discard unsaved changes?" title:"Discard" == false) do
			(
				GP_CurrentProjectSelected = pro
				ui_currentProject.selection = GP_CurrentProjectSelected

				return()
			)
		)

		GP_CurrentProjectSelected = newProject
		LoadProjectSettings()
		UpdateUI()
	)

	on PipeBoy_ProjectSettings open do
	(
		if (GP_CurrentProjectSelected == undefined or GP_CurrentProjectSelected == 0) do ( GP_CurrentProjectSelected = 1 )
		if (TMP_ProjectArray != undefined) do ( if (GP_CurrentProjectSelected > TMP_ProjectArray.count) do ( GP_CurrentProjectSelected = 1 ) )

		ui_currentProject.selection = GP_CurrentProjectSelected

		--Load in data
		LoadProjectSettings()

		--Update interface fields and values
		UpdateUI()
	)

	on ui_button_addProject pressed do
	(
		TempList = TMP_ProjectArray
		createDialog rlt_projectSettings_addProject
	)

	on ui_button_removeProject pressed do
	(
		if (queryBox "Are you sure you want to remove the project? This action is not undoable." title:"Remove project" == true) do
		(
			local pro = TMP_ProjectArray[GP_CurrentProjectSelected]

			--Delete from file
			delIniSetting PBS pro
			--Delete in local array
			deleteItem TMP_ProjectArray GP_CurrentProjectSelected

			GP_CurrentProjectSelected = 1

			--Save global settings
			setINISetting PBS "MainData" "g_Projects" (TMP_ProjectArray as string)

			LoadProjectSettings()

			UpdateUI()

			MessageBox ("Deleted project '" + pro + "' from file!")
		)
	)

	on ui_button_saveSettings pressed do
	(
		--Save settings to ".ini" file
		SaveProjectSettings()

		UpdateUI()
	)

	--[Actions when changing settings]--
	on ui_currentProject selected newProject do	( TrySetNewProject(newProject) )

	--Project
	on ui_Engine selected newEngine do ( LS.s_Engine = newEngine )
	on ui_projectRoot changed newString do ( LS.p_projectRoot = newString )
	on ui_projectSource changed newString do ( LS.p_projectSource = newString )

	--Removed for now
	--on ui_projectAsset changed newString do (	LS.p_projectAsset = newString )
	on ui_ImportFromRaw changed newState do ( LS.s_ImportFromRaw = newState	)
	on ui_preferredPrefixes changed newString do ( LS.s_PreferredPrefixes = newString )

	--[ Geometry ]--
	on ui_MeshGroupPrefix changed newString do ( LS.s_MeshGroupPrefix = newString )
	--Removed for now
	--on ui_ForwardAxis changed newAxis do ( LS.s_ForwardAxis = newAxis )

	--[ Animation ]--
	/*
	on ui_BonePrefix changed newString do (	LS.s_BonePrefix = newString	)
	on ui_AlignPrefix changed newString do ( LS.s_AlignPrefix = newString )
	on ui_BoneRoot changed newString do	( LS.s_BoneRoot = newString	)
	*/

	--[ Accesory ]--
	on ui_ac_folder changed newString do ( LS.s_ac_Folder = newString )
	--on ui_ac_prefix changed newString do ( LS.s_ac_Prefix = newString )
	--on ui_ac_findIntelligent changed newState do ( LS.s_ac_FindIntelligent = newState	)
	on ui_ac_lockRoot changed newState do (	LS.s_ac_LockRoot = newState	)
	on ui_ac_lockRootDepth changed newVal do ( LS.s_ac_LockRootDepth = newVal )
	on ui_ac_filePrefix changed newString do ( LS.s_ac_FilePrefix = newString )
	on ui_ac_fileSuffix changed newString do ( LS.s_ac_FileSuffix = newString )
	on ui_ac_removeFilePre changed newVal do ( LS.s_ac_RemoveFilePre = newVal )
	on ui_ac_removeFileSuf changed newVal do ( LS.s_ac_RemoveFileSuf = newVal )
)

rollout rlt_projectSettings_addProject "Add project" width:275 height:60
(
	edittext project_name "Project name:" fieldWidth:150 labelOnTop:true
	button okButton "Add" pos:[170,21]
	button cancelButton "Cancel" pos:[210,21]

	on okButton pressed do
	(
		if (project_name.text != "") then
		(
			append TMP_ProjectArray (project_name.text as string)
			PipeBoy_ProjectSettings.ui_currentProject.items = TMP_ProjectArray
			PipeBoy_ProjectSettings.ui_currentProject.selection = TMP_ProjectArray.count
			GP_CurrentProjectSelected = TMP_ProjectArray.count

			SaveProjectSettings query:#false

			destroyDialog rlt_projectSettings_addProject
		)
		else
		(
			messageBox "Enter a name" title:"Are you dumb?"
		)
	)

	on cancelButton pressed do
	(
		destroyDialog rlt_projectSettings_addProject
	)
)

--createDialog PipeBoy_ProjectSettings  pos:[1100,300]
--clearListener()
)
