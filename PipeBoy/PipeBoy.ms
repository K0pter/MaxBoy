
--Start PipeBoy--
(
persistent global currentProjectSelected, currentAssetSelected, PrintToConsole --Persistent handles
global PipeBoy --Rollout class handle
global PipeBoySettings
global PBS --Pipeboy settings file handle

global UnlinkFromParent
global ZeroRootToOrigin

fn getScriptLocation =
(
	local ScriptName = "PipeBoy.ms"
	local FileName = getThisScriptFilename()  as string
	local FilteredPath = replace FileName (FileName.count - ScriptName.count + 1) (ScriptName.count) ""

	free ScriptName
	free FileName
	
	--print(FilteredPath)
	
	return FilteredPath
)
	
fn printc str = 
(
	if (PrintToConsole == true) do (try(print(str))catch())
)

fn FreezeTransforms obj =
(
  local curObj = obj

  if classOf curObj.rotation.controller != Rotation_Layer do
  (
    -- Freeze rotation
    curObj.rotation.controller = Euler_Xyz()
    curObj.rotation.controller = Rotation_List()
    curObj.rotation.controller.available.controller = Euler_Xyz()

    -- Rename rotation controllers
    curObj.rotation.controller.SetName 1 "Frozen Rotation"
    curObj.rotation.controller.SetName 2 "Zero Euler XYZ"

    -- Set the new rotation controller as the active controller
    curObj.rotation.controller.SetActive 2
  )

  if classOf curObj.position.controller != Position_Layer do
  (
    -- Freeze position
    curObj.position.controller = Bezier_Position()
    curObj.position.controller = Position_List()
    curObj.position.controller.available.controller = Position_XYZ()

    -- Rename rotation controllers
    curObj.position.controller.SetName 1 "Frozen Position"
    curObj.position.controller.SetName 2 "Zero Pos XYZ"

    -- Set the new position controller as the active controller actual
    curObj.position.controller.SetActive 2

    -- Reset the position of the actual position controller to zero
    curObj.position.controller[2].x_Position = 0
    curObj.position.controller[2].y_Position = 0
    curObj.position.controller[2].z_Position = 0
  )
)

fn FilterForMeshes &FilterArray =
(
	local TempFilterArray = #()
	
	for i = 1 to FilterArray.count do
	(
		--if (ClassOf FilterArray[i] == Editable_Poly OR ClassOf FilterArray[i] == Editable_Mesh) do
		if (superclassof FilterArray[i] == GeometryClass) do
		(
			append TempFilterArray FilterArray[i]
		)
	)

	return TempFilterArray
)

fn LodGenerator &Obj Lods =
(
	clearSelection()
	disableSceneRedraw()
	
	try
	(
	with undo off
	(
		for lodObj in Obj do
		(
			try
			(
				local removeObjFromExport = findItem exportGroup lodObj
				deleteItem exportGroup removeObjFromExport
			)
			catch
			(
				print("Couldn't delete object from export group!")
			)

			maxOps.cloneNodes lodObj cloneType:#copy newNodes:&SafeLodCopy
			append cleanGroup SafeLodCopy
			tempLodObj = SafeLodCopy[1]
			tempLodObj.name = ((TrimRight lodObj.name "0123456789") + "_LOD0")
		
			append exportGroup tempLodObj
			
			for i = 1 to Lods do
			(
				maxOps.cloneNodes tempLodObj cloneType:#copy newNodes:&SafeLodStepCopy
				append cleanGroup SafeLodStepCopy
				LodStepObject = SafeLodStepCopy[1]
				LodStepObject.name = ((TrimRight tempLodObj.name "0123456789") +  i as string)
				
				Optimizer = ProOptimizer OptimizationMode:1

				Optimizer.VertexPercent = (75 / i)
				Optimizer.KeepUV = true
				Optimizer.LockUV = true
				
				Optimizer.KeepNormals = true
				Optimizer.KeepVC = true
				
				Optimizer.MergePoints = true
				Optimizer.MergePointsThreshold = 5
				
				addmodifier LodStepObject Optimizer
				
				clearSelection()
				select LodStepObject
				
				$.modifiers[#ProOptimizer].Calculate = true
				CollapseStack LodStepObject
				ConvertTo LodStepObject Editable_Poly
				
				--LodStepObject.position.y += (250 * i)
				
				append exportGroup LodStepObject
				
				--free LodStepObject
			)
			
			--free tempLodObj
		)
	)
	)
	catch(enableSceneRedraw())
	
	enableSceneRedraw()
	clearSelection()
)

rollout PipeBoy "PipeBoy" width:325 height:90
(		
	global getName = (getFilenameFile  maxFileName)
	global exportGroup = #()
	global cleanGroup = #()
	global projectArray = #()
	
	fn RefreshRollouts = 
	(
		global ro_m = PipeBoy.UI_RolloutGroup_Main
		global ro_a = PipeBoy.UI_RolloutGroup_Asset
		global ro_g = PipeBoy.UI_RolloutGroup_General
		global ro_p = PipeBoy.UI_RolloutGroup_Project
	)
	
	fn RotatePivotOnly obj = 
	(
		/*
		1 = X-Forward
		2 = - X-Forward
		3 = Y-Forward
		4 = - Y-Forward
		
		case s_Engine of
		(
			1:
			(
				local rotValInv = case s_ForwardAxis of
				(
					1: inverse(eulerToQuat(eulerAngles 90 0 90))
					2: inverse(eulerToQuat(eulerAngles 90 0 -90))
					3: inverse(eulerToQuat(eulerAngles 90 0 180))
					4: inverse(eulerToQuat(eulerAngles 90 0 0))
				)
			)
			
			2:
			(
				local rotValInv = case s_ForwardAxis of
				(
					1: inverse(eulerToQuat(eulerAngles 90 0 90))
					2: inverse(eulerToQuat(eulerAngles 90 0 -90))
					3: inverse(eulerToQuat(eulerAngles 90 0 180))
					4: inverse(eulerToQuat(eulerAngles 90 0 0))
				)
			)
		)
		*/
		
		--rotValInv = inverse(eulerToQuat(eulerAngles -90 0 90))
		--RotValInv = eulerToQuat(eulerAngles 90 0 90)
		--in coordsys world obj.objectOffsetRot = RotValInv
		
		--in coordsys local rotate TempPivot (angleaxis 90 [1,0,0])
		--in coordsys local rotate TempPivot (angleaxis 90 [0,1,0])
		
		local RotValInv = inverse (EulerAngles 90 0 90 as quat)

		animate off in coordsys local obj.rotation*=RotValInv
		obj.objectOffsetPos*=RotValInv
		obj.objectOffsetRot*=RotValInv
	)

	fn exportProcess ExportType CurrentProjectKey =
	(		
		local pro = projectArray[CurrentProjectKey] as string
		
		RefreshRollouts()
		
		--Update filename to base asset name from
		getName = (getFilenameFile  maxFileName)
		
		thePlugin = pluginManager
		thePlugin.loadClass FBXEXPORTER

		FBXExporterSetParam "SmoothingGroups" True
		FBXExporterSetParam "TangentSpaceExport" True
		FBXExporterSetParam "ASCII" False
		FBXExporterSetParam "FileVersion" "FBX201400"
		FBXExporterSetParam "Cameras" False
		FBXExporterSetParam "Lights" False
		FBXExporterSetParam "PreserveInstances" True
		FBXExporterSetParam "ScaleFactor" 1.0
		FBXExporterSetParam "ShowWarnings" False
		
		case ExportType of
		(
			1:
			(
				FBXExporterSetParam "Animation" False
				
				clearSelection
				execute "$exportGroup"
			)
			
			2:
			(
				FBXExporterSetParam "Animation" True

				FBXExporterSetParam "BakeAnimation" True
				FBXExporterSetParam "BakeResampleAnimation" True
				
				FBXExporterSetParam "BakeFrameStart" ro_m.anim_range_start.value
				FBXExporterSetParam "BakeFrameEnd" ro_m.anim_range_end.value
			)
		)
		
		case s_Engine	of
		(
			1:
			(
				FBXExporterSetParam "UpAxis" "Y"
				
				local p_EngineSpecificAssetPath = ("Assets\\")
			)
			
			2:
			(
				FBXExporterSetParam "UpAxis" "Z"
				
				local p_EngineSpecificAssetPath = ("Content\\")
			)
		)
		
		--Set export params
		FBXExporterSetParam "PushSettings"

		local p_length = ((getINISetting PBS pro "p_projectSource").count)
		--Previously subtracted the extra asset path dir
		--local p_length = ((getINISetting PBS pro "p_projectSource").count) + (p_EngineSpecificAssetPath.count)
		
		local p_subPath = replace (maxFilePath as string) 1 (p_length) ""
		
		--Check if not animation asset type
		if (ro_a.IsType.selection != 4) then
		(
			local p_filenameFolderPath = ("\\" + getName + "\\")
		)
		else
		(
			local p_filenameFolderPath = ""
		)
		
		--Build final path to file export locatio
		if (s_ImportFromRaw == false) then
		(
			local p_fileExportPath = (p_ProjectRoot + p_EngineSpecificAssetPath + p_projectAsset + p_subPath)
			--Removed due to not really making sense
			--local p_fileExportPath = (p_ProjectRoot + p_EngineSpecificAssetPath + p_projectAsset + p_subPath + p_filenameFolderPath)
		)
		else
		(
			local p_fileExportPath = (maxFilePath as string)
		)
		
		if NOT doesFileExist p_fileExportPath OR NOT getFileAttribute p_fileExportPath #directory do 
		(
			--Path folder not found, create folder
			printc("Path folder not found, creating folder.")
			makeDir p_fileExportPath
		)
		
		fileExportName = (p_fileExportPath + getName + ".fbx") as string
		exportfile (fileExportName) #noprompt selectedOnly:true using:thePlugin
		
		print("Exported to file: " + fileExportName)
		
		clearSelection()
		enableSceneRedraw()
	)
	
	--Dependency class
	fn PrepareMeshForExport group_mesh generate_lods lods_amount =
	(
		RefreshRollouts()
		
		if ($ == undefined and group_mesh == false) do
		(
			clearListener()
			print("Nothing selected, quitting...")
			return()
		)
		
		global cleanGroup = #()
		global exportGroup = #()
		global GroupArray = #()
		
		free cleanGroup
		free exportGroup
		free GroupArray
	
		try
		(
			disableSceneRedraw()
			
			with undo off
			(
				clearlistener()

				--Create root export object for axis conversion
				local ExportParent = Point Size:500 Name:"ExportParent"
				RotatePivotOnly(ExportParent)
				FreezeTransforms(ExportParent)
				
				append exportGroup ExportParent
				append cleanGroup ExportParent

				--Clone export objects for non-destructive processing
				maxOps.cloneNodes selection cloneType:#copy newNodes:&SafeCopies
				append cleanGroup SafeCopies
				
				--Make all instances in selection unique (Will be ignored otherwise)
				InstanceMgr.MakeObjectsUnique SafeCopies #individual
				
				--Clear selection to set up proper selection for export
				clearSelection()
				select SafeCopies				
				
				if (s_MeshGroupPrefix == undefined) do (s_MeshGroupPrefix = "g_")
					
				if (group_mesh == true) then
				(	
					--Collect mesh groups in selection
					for obj in SafeCopies do
					(
						if (matchPattern obj.name pattern:(s_MeshGroupPrefix + "*") == true) do
						(
							printc("Found group object: " + obj.name + " - adding to array")
							append GroupArray obj
						)
					)
					
					--Process mesh groups
					for g in GroupArray do
					(
						printc("\n")
						printc("[---------Creating Mesh Group---------]")
						printc("Group object: " + g.name)

						clearSelection()
						select g.children
						
						local CombiningGroup = FilterForMeshes(selection)
						
						printc("\nGroup objects {")
						printc(CombiningGroup as array)
							
						local GroupName = replace (trimRight (g.name as string) "0123456789") 1 s_MeshGroupPrefix.count ""
						
						local GroupParent = Point Size:100 Name:(("g_" + GroupName) as string)
						RotatePivotOnly(GroupParent)
						append exportGroup GroupParent
						append cleanGroup GroupParent
						
						local CombinedMesh = Editable_Mesh name:(("mg_" + GroupName) as string)
						convertTo CombinedMesh Editable_Poly
						
						GroupParent.parent = ExportParent
						GroupParent.position = g.position
						CombinedMesh.position = g.position
						
						printc("\nCombined mesh: " + CombinedMesh.name)
						printc("\n[Starting grouping process]\n")
						
						for c in CombiningGroup do
						(								
							collapseStack c
							convertTo c Editable_Poly
							
							printc("Adding mesh [ " + c.name + " ] to: " + CombinedMesh.name)
														
							polyop.attach CombinedMesh c
						)

						--Fix pivot
						if (ZeroRootToOrigin == true) then
						(
							in coordsys world CombinedMesh.objectOffsetPos = [0,0,0]
							in coordsys world CombinedMesh.objectOffsetRot = (eulerangles 0 0 0)
						)
						else
						(
							--CombinedMesh.objectOffsetPos = g.position
							--CombinedMesh.objectOffsetRot = g.rotation
							ResetTransform CombinedMesh
						)
						
						if (UnlinkFromParent == true) 
						then
						(CombinedMesh.parent = ExportParent)
						else
						(CombinedMesh.parent = GroupParent)		
						
						RotatePivotOnly(CombinedMesh)
						
						--Add combined object to group
						append exportGroup CombinedMesh
						append cleanGroup CombinedMesh
					)
				)
				else
				(
					--Regular export selection
					local CombiningGroup = FilterForMeshes(selection)					
					
					for i=1 to CombiningGroup.count do
					(
						c = CombiningGroup[i]
						
						collapseStack c
						convertTo c Editable_Poly
						
						local CurrentParent = parent
						parent = undefined
						
						if (UnlinkFromParent == true) then 
						(
							c.parent = ExportParent
						) 
						else 
						(
							if (CurrentParent == undefined) then	(c.parent = ExportParent) else (c.parent = CurrentParent)
						)
						
						RotatePivotOnly(c)
						
						append exportGroup c
						--append cleanGroup c
					)
				)
			)
		)
		catch
		(
			enableSceneRedraw()
				
			for o in cleanGroup do
			(
				try(delete o)catch()
			)
			
			for o in SafeCopies do
			(
				try(delete o)catch()
			)
			
			messageBox "Something went wrong!" title:"Error"
			
			return()
		)

		if (generate_lods) do
		(
			local LodMeshsGroups = FilterForMeshes exportGroup
			LodGenerator LodMeshsGroups lods_amount
		)
		 
		--Done!
		printc("\nOperation done!")
		printc("Export group {")
		printc(exportGroup)

		rotate ExportParent (eulerangles 0 0 -90)
		
		--Collect combined objets and export them, then clean em' out			
		clearSelection()
		select exportGroup

		exportProcess 1 currentProjectSelected
		
		clearSelection()
		
		for o in cleanGroup do
		(
			try(delete o)catch()
		)
		
		for o in SafeCopies do
		(
			try(delete o)catch()
		)
		
		free cleanGroup
		free exportGroup
	)

	fn LoadVariables = 
	(		
		--Setup which project to load from file
		tempProjectArray = (getINISetting PBS "MainData" "g_Projects")
		global projectArray = execute tempProjectArray
		
		if (currentProjectSelected == undefined OR currentProjectSelected == 0) then
			t_selectProject = 1
			else
			t_selectProject = currentProjectSelected

		global currentProjectSelected = t_selectProject
		
		if (projectArray[t_selectProject] != undefined) then
		(	
			local pro = (projectArray[t_selectProject] as string)
			
			global p_ProjectRoot = (getINISetting PBS pro "p_projectRoot")
			global p_ProjectSource = (getINISetting PBS pro "p_projectSource")
			global p_projectAsset = (getINISetting PBS pro "p_projectAsset")
			
			global s_Engine = (getINISetting PBS pro "s_Engine") as Integer
			global s_ImportFromRaw = (getINISetting PBS pro "s_ImportFromRaw") as booleanClass
			global s_ForwardAxis = getINISetting PBS pro "s_ForwardAxis" as Integer
			global s_MeshGroupPrefix = getINISetting PBS pro "s_MeshGroupPrefix"
			
			global s_BonePrefix = getINISetting PBS pro "s_BonePrefix"
			global s_BoneRoot = getINISetting PBS pro "s_BoneRoot"
			global s_AlignPrefix = getINISetting PBS pro "s_AlignPrefix"
			
			print("Loaded project: " + pro)
		)
		else
		(
			MessageBox "Project seems to be missing!" title:"Missing project!"
		)
	)
	
	fn getChildren obj:selection[1] = 
	(
		execute ("$'" + (obj.name) + "'/*/.../*")
	)
	
	--Construct Base UI "Frame" for rollout windows
	subRollout UI_BaseRollout width:325 height:90 pos:[-1,-1]
	
	rollout UI_RolloutGroup_Main "Export"
    (		
		group "Mesh"
		(
			button Export "Export" width:125 pos:[20,20]
			button ExportSelection "Export Selection" width:125 pos:[155,20]
		)
		
		group "Animation"
		(
			button ExportAnimation "Export Animation" width:125 pos:[20, 70]
			
			spinner anim_range_start "" pos:[160,73] width:50 height:16 range:[-10000,10000,normTime 0] type:#integer
			spinner anim_range_end  "to  " pos:[160+70,73] width:50 height:16 range:[-10000,10000,normTime 1] type:#integer
		)
		
        on UI_RolloutGroup_Main rolledUp bState do
        (
            if (bState == true) then
            (
				UI_BaseRollout.height += UI_RolloutGroup_Main.height
				PipeBoy.height += UI_RolloutGroup_Main.height
            )
            else
            (
				UI_BaseRollout.height -= UI_RolloutGroup_Main.height
				PipeBoy.height -= UI_RolloutGroup_Main.height
            )
        )
		
		on Export pressed do
		(	
			select $*
			
			if (ro_a == undefined) do (RefreshRollouts())

			PrepareMeshForExport ro_a.meshGrouper.state ro_a.generateLods.state ro_a.lodsAmount
		)
		
		on ExportSelection pressed do
		(	
			if (ro_a == undefined) do (RefreshRollouts())
				
			PrepareMeshForExport ro_a.meshGrouper.state ro_a.generateLods.state ro_a.lodsAmount
		)
		
		on ExportAnimation pressed do
		(
			clearSelection
			disableSceneRedraw() 

			if (isValidNode(getNodeByName (s_BoneRoot as string)) == false) do
			(
				messageBox "No root bone to select in scene!" title:"No root bone!"
				enableSceneRedraw()
				return()
			)
			
			try
			(
				select (getNodeByName (s_BoneRoot as string))
				select $/...*
				
				local nodeSelection = selection
				local boneSelection = #()
					
				for i = 1 to nodeSelection.count do
				(
					obj = nodeSelection[i]
					
					boneMatchResult = matchPattern (obj.name) pattern:((s_BonePrefix as string) + "*") ignoreCase:false
					alignMatchResult = matchPattern (obj.name) pattern:((s_AlignPrefix as string) + "*") ignoreCase:false
					
					if (boneMatchResult == true OR alignMatchResult == true) do
					(
						append boneSelection obj
					)
				)
				
				clearSelection
				
				select boneSelection
					
				exportProcess 2 ro_p.currentProject.selection
			)
			catch
			(
				enableSceneRedraw()
			)
		)
    )
		
	rollout UI_RolloutGroup_Asset "Asset Settings"
    (		
		group "Asset Settings"
		(	
			dropdownlist IsType "Asset Type" items:#("Architecture", "Prop", "Detail", "Animation", "Other") width:125
			
			checkbox meshGrouper "Mesh grouper" checked:true
			checkbox generateLods "Generate lods" checked:false
			spinner lodsAmount "Lods" range:[1,6,2] type:#integer width:50 pos:[125, 92]
		)
		
		on IsType selected NewType do 
		(
			currentAssetSelected = NewType
		)
		
		on UI_RolloutGroup_Asset open do
		(
			IsType.selection = currentAssetSelected
		)
		
        on UI_RolloutGroup_Asset rolledUp bState do
        (
            if (bState == true) then
            (
				UI_BaseRollout.height += UI_RolloutGroup_Asset.height
				PipeBoy.height += UI_RolloutGroup_Asset.height
            )
            else
            (
				UI_BaseRollout.height -= UI_RolloutGroup_Asset.height
				PipeBoy.height -= UI_RolloutGroup_Asset.height
            )
        )
		
		on UI_RolloutGroup_Asset open do
		(
			UI_RolloutGroup_Asset.open = false
		)
    )
	
	rollout UI_RolloutGroup_General "General Settings"
    (		
		group "General Settings"
		(	
			checkbox ZeroRoot "Zero Root" checked:false
			checkbox Unlink "Unlink" checked:false
			checkbox PrintMessages "Print to log?" checked:PrintToConsole
		)
		
		on PrintMessages changed newState do
		(
			PrintToConsole = newState
		)
		
		on Unlink changed newState do
		(
			UnlinkFromParent = newState
		)
		
		on ZeroRoot changed newState do
		(
			ZeroRootToOrigin = newState
		)

        on UI_RolloutGroup_General rolledUp bState do
        (
            if (bState == true) then
            (
				UI_BaseRollout.height += UI_RolloutGroup_General.height
				PipeBoy.height += UI_RolloutGroup_General.height
            )
            else
            (
				UI_BaseRollout.height -= UI_RolloutGroup_General.height
				PipeBoy.height -= UI_RolloutGroup_General.height
            )
        )
		
		on UI_RolloutGroup_General open do
		(
			UI_RolloutGroup_General.open = false
		)
    )
	
	rollout UI_RolloutGroup_Project "Project Settings"
    (    
		group "Project Settings"
		(	
			dropdownlist currentProject "Project" width:125
			button editProjectSettings "Edit project settings" align:#left
		)
		
		on UI_RolloutGroup_Project open do
		(
			UI_RolloutGroup_Project.open = false
		)
		
        on UI_RolloutGroup_Project rolledUp bState do
        (
            if (bState == true) then
            (
				UI_BaseRollout.height += UI_RolloutGroup_Project.height
				PipeBoy.height += UI_RolloutGroup_Project.height
            )
            else
            (
				UI_BaseRollout.height -= UI_RolloutGroup_Project.height
				PipeBoy.height -= UI_RolloutGroup_Project.height
            )
        )
		
		on editProjectSettings pressed do
		(
			fileIn PipeBoySettings
		)
		
		on currentProject selected newProject do 
		(
			if (newProject != undefined) then
			(
				currentProjectSelected = currentProject.selection
				LoadVariables()
			)
			else
			(
				MessageBox "Project seems to be missing!" title:"Missing project!"
				currentProjectSelected = 1
			)
		)
    )
	
	on PipeBoy open do
	(		
		--Fix initialized persistent variables
		if (currentProjectSelected == 0  OR currentProjectSelected == undefined) do (currentProjectSelected = 1)
		if (currentAssetSelected == 0  OR currentAssetSelected == undefined) do (currentAssetSelected = 1)
		if (PrintToConsole == undefined) do (PrintToConsole = false)
		
		addSubRollout UI_BaseRollout UI_RolloutGroup_Main
		addSubRollout UI_BaseRollout UI_RolloutGroup_Asset
		addSubRollout UI_BaseRollout UI_RolloutGroup_General
		addSubRollout UI_BaseRollout UI_RolloutGroup_Project
		
		global ro_m = PipeBoy.UI_RolloutGroup_Main
		global ro_a = PipeBoy.UI_RolloutGroup_Asset
		global ro_g = PipeBoy.UI_RolloutGroup_General
		global ro_p = PipeBoy.UI_RolloutGroup_Project
		
		ro_a.IsType.selection = 1
		
		global path_settings = getScriptLocation() --Get script location on computer to load project data
		global PBS = (path_settings + "Pipeboy_Settings.ini") --Setup settings file
		global PipeBoySettings = (path_settings + "PipeBoy_ProjectSettings.ms")
		--Setup interface data
		LoadVariables()
		
		ro_p.currentProject.items = projectArray
		ro_p.currentProject.selection = currentProjectSelected
		
		enableSceneRedraw()
		renderSceneDialog.update()
	)
)

)
try(destroyDialog PipeBoy)catch()
createDialog PipeBoy style:#(#style_toolwindow, #style_sysmenu) pos:[1100,150]