/*/////////////////////////////////////////
Toolboy is a collection of neatly packed 
macros and tools to speed up general tasks.
/////////////////////////////////////////*/

--Start ToolBoy--
(
rollout ToolBoy "ToolBoy"
(
	--Global settings
	global s_usePrefix = false
	global s_bPrefix = "b_"
	global s_cPrefix = "c_"
	global s_print = false

	--Global arrays
	global nodeList = #()

	subRollout UI_Base width:190 height:70 pos:[-1,-1]

	include "$userScripts\MaxBoy\MaxBoy_Functions.ms"
	
	rollout UI_Settings "General"
	(
		group ""
		(
			checkbox usePrefix "Use Prefix" toolTip:"Use prefix to select objects?"
			edittext bPrefix "Bone prefix:" text:"b_" width:125
			edittext cPrefix "Controller prefix:" text:"c_" width:125
			button SelectChildren "Select children"	
		)

		group "Misc"
		(
		    button GiveDummies "Give Dummies" width:150 align:#left toolTip:"Add dummy object at selected object(s) transforms."

		    multiListBox DummyType "Type" items:#("Cross", "Box", "Axis Tripod", "Center Marker") selection:#(1) height:4
		    checkbox DummyInhParent "Inherit parent"
		    checkbox DummyInhScale "Inherit scale"
		    spinner DummyScale "Size" range:[0,1000,10] width:100 align:#left
		)

		group "Diagnose"
		(
			button nodeCheckup "Checkup!" width:150 align:#left toolTip:"Return bad transforms and other data"
		)

		--Handle window scaling when rolled up
		on UI_Settings rolledUp State do (resizeWindow ToolBoy State UI_Settings)

		on usePrefix changed State do
		(
			--Set the local setting to new state
			s_usePrefix = State
			--print("Set new prefix state to: " + (State as string))
		)

		on bPrefix changed newPrefix do
		(
			--Update global setting
			s_bPrefix = newPrefix
			--print("Set new bone prefix to: " + (newPrefix as string))
		)

		on cPrefix changed newPrefix do
		(
			--Update global setting
			s_cPrefix = newPrefix
			--print("Set new controller prefix to: " + (newPrefix as string))
		)

		on SelectChildren pressed do
		(
			if selection.count == 1 then
			(
				selectionArray = #($)
				
				select(getChildren())

				join selectionArray selection
				
				select selectionArray
				Free selectionArray
			)
			else
			(
				messageBox "Multiple or no nodes are not supported!" title:"Error..."
			)
		)

		on GiveDummies pressed do
		(
			clearListener()

			if (selection.count == 0) do 
			(
				messageBox "Nothing selected, quitting." title:"Error!"
				return()
			)
			
			with redraw off 
			(
				--Sort arrays to align with hierarchy indexes
				local tempArray = sortToHierarchy(selection as array)

				if (tempArray == undefined) do (return())

				local parentArray = getHierarchyIndex(tempArray)
				local pointArray = #()

				--Dummy creation
				for i = 1 to tempArray.count do 
				(	
					o = tempArray[i]
					
					if (DummyInhScale.state == true) then
					(
						ps = getRelativeScale(o) / 2
					)
					else
					(
						ps = DummyScale.value
					)
					

					p = Point Size: (ps) 
					p.transform = o.transform
					p.scale = [1,1,1]
					p.name = ("point:" + o.name)

					p.cross = DummyType.selection[1]
					p.box = DummyType.selection[2]
					p.centermarker = DummyType.selection[3]
					p.axistripod = DummyType.selection[4]

					append pointArray p
				)

				print("[Parent array]")
				print(parentArray)
				print("[Point array]")
				print(pointArray)

				--Parenting
				if (DummyInhParent.state == true) do 
				(
					for i = 1 to pointArray.count do
					(
						local p = pointArray[i] --Point
						local pr = (parentArray[i] - 1) --Parent ref (get one step up in hierarchy)

						if (pr != 0) then
						(
							p.parent = pointArray[pr]
						)
						else
						(
							p.parent = undefined
						)
					)
				)
			)
		)

		on nodeCheckup pressed do
		(
			local aNodes = #() --All nodes
			local bNodes = #() --Bad nodes

			local r_badScale = false --Has bad scale?

			--Do initial bone rig check

			if (selection.count == 0) then
			(
				local bArray = getPrefixObjects(s_bPrefix) --Get all bone objects
				local cArray = getPrefixObjects(s_cPrefix) --Get all controller objects

				--Add them all together
				Join aNodes bArray
				Join aNodes cArray
			)
			else
			(
				aNodes = selection as array
			)

			for o in aNodes do
			(
				--Check scale (should be [1,1,1] for proper use)
				if (o.scale != [1,1,1]) do
				(
					append bNodes o

					r_badScale = true
				)
			)

			if (r_badScale) do
			(
				rollout dumpMessage "Dump" width:380 height:350
				(
					local bn = #()

					label badScales "[Bad scale nodes]" align:#left
					MultiListBox bs_n "Nodes" width:175 height:15 pos:[15,40]
					MultiListBox bs_ns "Scales" width:165 height:15 pos:[200,40]

					button ok "OK" pos:[145,300] width:100 align:#center
					button fix "Fix" pos:[90,275] width:100 align:#center
					button fixAll "Fix All" pos:[200,275] width:100 align:#center

					button refresh "Refresh" pos:[145,300] width:100 align:#center

					on ok pressed do
					(
						--Close dialogue window with button
						DestroyDialog dumpMessage
					)

					on fix pressed do
					(
						local sel = bs_n.selection
						if sel.isEmpty do (return())
						sel = sel as array

						local selectedNodes = #()

						for i = 1 to sel.count do
						(
							local n = sel[i]
							append selectedNodes bn[n]
						)
						
						if (selectedNodes.count > 0) do (fn_resetScales(selectedNodes))

						bs_ns.items = (for o in bn collect (o.scale as string))
					)

					on fixAll pressed do
					(
						fn_resetScales(bn)

						bs_ns.items = (for o in bn collect (o.scale as string))
					)				
				)
				
				CreateDialog dumpMessage
				--Has to be placed after rollout creation!
				Join dumpMessage.bn bNodes

				dumpMessage.bs_n.items = (for o in bNodes collect o.name)
				dumpMessage.bs_ns.items = (for o in bNodes collect (o.scale as string))
			)
		)
	)

	rollout UI_Rigging "Rigging"
	(
		group "Constraints"
		(
			--button testSort "Test Sort"
			button AddConstraints "Add Constraints" width:150 align:#left toolTip:"Add constraints based on proximity-based binding, for selected object(s)."
			checkbox OrientationRelative "Relative Orientation" checked:true toolTip:"Should the rotation constraint be relative or absolute"
			checkbox AddOrientation "Rotation Constraint" checked:true toolTip:"Add rotation constraint."
			checkbox AddPosition "Position Constraint" toolTip:"Add position constraint."
			pickButton ConstraintTarget "Target Root" pos:[14,112]
			edittext ctTarget "" pos:[90,114] fieldWidth:70 height:20 readOnly:true
		)

		group "Controllers"
		(
			button AddControllers "Add Rig Controllers" width:150 align:#left
			checkbox BoneMode "Bone mode" checked:true toolTip:"Use this for prefix-based auto-renaming on generated controllers."
			checkbox OrientToChild "Orient towards child" checked:true toolTip:"Should the controller point towards the next child or be oriented like the reference bone?"
			
			dropdownlist CntrlType "Shape" items:#("Circle", "Box") selection:2
			checkbox CntrlInhScale "Inherit scale"
			spinner CntrlScale "Radius" range:[0,1000,4] width:100 align:#left
		)

		group "Scale" 
		(
			button ResetScales "Re-set Scales" width:150 align:#left
		    --New function avoids extra cycle passes!
		    --spinner Cycles "Cycles" range:[0,1000,10] type:#integer width:100 align:#left toolTip:"Hierarchical, recursive scaling (Steps in hierarchiy)."
		)

		group "Controllers"
		(
			button RegularController "Re-set Controllers" width:150 align:#left
			button XrefController "Xref Controllers" width:150 align:#left
		)

		--Handle window scaling when rolled up
		on UI_Rigging rolledUp State do (resizeWindow ToolBoy State UI_Rigging)

		on testSort pressed do
		(
			local shuffle = #()
			local aba = (Selection as array)

			sortToHierarchy &aba &shuffle

			--getHierarchy(tArray)

			print(aba)
			print(shuffle)
			--getHierarchyIndex(selection as array)
		)

		on AddControllers pressed  do
		(	
			clearListener()
			print("Generating controllers!")
			
			with redraw off 
			(
				local collectionArray = collectObjects s_bPrefix

				if (collectionArray == undefined) then 
				(
					messageBox "Empty selection, exiting controller creation..." title:"Error!"
					print("Exiting controller creation...")
					return()
				)
				else
				(
					if (collectionArray.count == 0) do
					(
						messageBox "Empty selection, exiting controller creation..." title:"Error!"
						print("Exiting controller creation...")
						return()
					)
				)

				--Copy nodes to make controllers for
				local controllerCopies = #()
				CopyNodes collectionArray #copy &controllerCopies

				--Create container for node hierarchy indexes
				local indexArray = #()

				--Sort controller array to make isolating the parents easier
				sortToHierarchy &controllerCopies &indexArray

				--Create local node to parent controllers to
				local cntrlParent = Point Size:20 name:"CntrlParent"

				for i = 1 to indexArray.count do 
				(
					--If parent isn't amongst the copies, parent to dummy parent
					local localParent = findItem controllerCopies controllerCopies[i].parent					

					--If I'm at the top or have no other parent amongst the copies, copy to dummy
					if (indexArray[i] == 1 or localParent == 0) do
					(
						controllerCopies[i].parent = cntrlParent
					)
				)

				local controllerArray = #()			

				for i = 1 to controllerCopies.count do 
				(	
					local o = controllerCopies[i]

					if (o != undefined) then
					(
						local Type = CntrlType.selection --Controller shape type
						local cnt --Initialize controller variable

						if (Type == 1) do
						(
							--Create controller with settings
							local rad = 20

							if (CntrlInhScale.state == true) then
							(
								rad = getRelativeScale(o) / 3
							)
							else
							(
								rad = CntrlScale.value
							)
							
							cnt = circle radius: rad
							cnt.render_thickness = (rad / 8)

							cnt.transform = o.transform
							cnt.scale = [1,1,1]

							RotatePivotOnly cnt (eulerangles 0 -90 0)
						)

						if (Type == 2) do
						(
							--Create controller with settings

							--Find leading child with most children (to avoid twist bones and others)
							local storedLeader = o.children[1]
							local tChildren = o.children

							if (tChildren != undefined) do
							(
								for leaderObj in tChildren do
								(
									if (leaderObj.children.count > storedLeader.children.count) do
									(
										storedLeader = leaderObj
									)
								)
							)

							local c = storedLeader --Child target
							local b_height = 5

							if (c == undefined) then
							(
								b_height = getRelativeScale(o) / 1
							)
							else
							(
								b_height = distance o c
							)

							local b_width = CntrlScale.value
							cnt = Box height:b_height width:b_width length:b_width

							cnt.transform = o.transform
							cnt.scale = [1,1,1]
							
							--in coordsys local rotate cnt (EulerAngles 0 90 0)
							RotatePivotOnly cnt (eulerangles 0 90 0)
						)

						if (OrientToChild.checked == true) do
						(
							if (o.children.count >= 1) do
							(
								local upNode = point size:5 name:"tUpnode"
								upNode.transform = o.transform
								in coordsys #local upNode.pos.z += 10

								lookAtChild = LookAt_Constraint relative:false pickUpNode:upNode upnode_world: false StoUP_axis:2
								lookAtChild.appendTarget o.children[1] 100

								cnt.rotation.controller = lookAtChild

								local storedTransform = cnt.transform
					
								cnt.Transform.controller = prs()
								cnt.Position.controller = Position_XYZ()
								cnt.Rotation.controller = Euler_XYZ()
					
								cnt.transform = storedTransform

								delete upNode
							)
						)

						cnt.parent = o.parent

						for tChild in o.children do (tChild.parent = cnt)

						append controllerArray cnt

						--Naming (remove "001" from copies naming convention)
						local tempName = replace (o.name) (o.name.count - 3) 3 ""

						--Add bone prefix if using bone mode
						if (BoneMode.checked == true) do
						(
							tempName = replace tempName 1 s_cPrefix.count ""
						)

						cnt.name = (s_cPrefix + tempName)

						continue
					)
					else
					(
						print("Selection is currently undefined. Stopping!")
					)
				)

				for obj in controllerCopies do (delete obj)

				clearSelection
				select controllerArray
			)	
		)
		
		on AddConstraints pressed  do
		(	
			--Get object selection for action
			local _BoneArray = #()
			local _ControllerArray = #()

			if (s_usePrefix == true) then
			(
				_BoneArray = getPrefixObjects(s_bPrefix)
				_ControllerArray = getPrefixObjects(s_cPrefix)
			)
			else
			(
				if (selection.count != 0) then
				(
					_ControllerArray = (selection as array)
					_BoneArray = getChildren(ConstraintTarget.object)	
				)
				else
				(
					messageBox "No selection, exiting." title:"Error!"
					return()
				)
			)
			
			--format "Ba: %; \n" _BoneArray
			--format "Ca: %; \n" _ControllerArray
			
			for i = 1 to _ControllerArray.count do 
			(	
				oA = _ControllerArray[i]
				
				for j = 1 to _BoneArray.count do
				(
					oB = _BoneArray[j]
					
					if (distance oA.position oB.position < 0.01) do
					(
						--print("Constraining: " + oA.name + " to " + oB.name)
						if (AddOrientation.state == true) do
						(
							oB.rotation.controller = Orientation_Constraint ()
							oB.rotation.controller.appendTarget oA 100
							
							if (OrientationRelative.state == true) do
							(
								oB.rotation.controller.relative = on
							)

							print("Orientation constrained [" + oB.name + "] to [" + oA.name + "]")
						)
						
						if (AddPosition.state == true) do
						(
							oB.position.controller = Position_Constraint ()
							oB.position.controller.appendTarget oA 100

							print("Position constrained [" + oB.name + "] to [" + oA.name + "]")
						)
					)
				)
			)
		)

		on ResetScales pressed do
		(
			--Moved to generic function for multi-usage
			local scaleArray = (selection as array)

			fn_resetScales(scaleArray)
		)
		
		on RegularController pressed do
		(
			clearListener()
			print("Starting operation!")
			
			with redraw off 
			(
				local tempArray = collectObjects 1
				
				--print("List is ready!")
				print("...")

				clearSelection()
				
				--macros.run "Track View" "LaunchDopeSheetEditor"	
				
				for i=1 to tempArray.count do 
				(	
					currentObject = tempArray[i]
					
					if (currentObject != undefined) then
					(
						--select currentObject
						--print("Applying Xref to: " + currentObject.name as string)
						--print($.Transform.controller)
						
						boob = Point Size:5
						boob.transform = currentObject.transform
						
						currentObject.Transform.controller = prs()
						currentObject.Position.controller = Position_XYZ()
						currentObject.Rotation.controller = Euler_XYZ()
						
						currentObject.transform = boob.transform
						delete boob
						
						continue
					)
					else
					(
						print("Selection is currently undefined. Stopping!")
					)
				)
			)
			
			print("Done!")
			
			redrawViews()
		)

		on XrefController pressed do
		(
			clearListener()
			print("Starting operation!")
			
			with redraw off 
			(
				local tempArray = collectObjects 1
				
				--print("List is ready!")
				print("...")

				clearSelection()
				
				--macros.run "Track View" "LaunchDopeSheetEditor"	
				
				for i=1 to tempArray.count do 
				(	
					currentObject = tempArray[i]
					
					if (currentObject != undefined) then
					(
						--select currentObject
						--print("Applying Xref to: " + currentObject.name as string)
						--print($.Transform.controller)
						
						currentObject.Transform.controller = XRef_Controller ()
						continue
					)
					else
					(
						print("Selection is currently undefined. Stopping!")
					)
				)
			)
			
			print("Done!")
			
			redrawViews()
		)

		on ConstraintTarget picked newTarget do
		(
			--Update constraint target text
			ctTarget.text = newTarget.name
		)
	)
	
	rollout UI_Mesh "Mesh"
	(
		group "Mesh Commands"
		(
			button ResetXforms "Reset Xforms" width:150 align:#left
			button RefreshSkinnedMesh "Refresh skinned mesh" width:150 align:#left
		)

		group "Instancing"
		(
			button RefreshInstances "Refresh Instances" width:150 align:#left
			label refLabel "[Instance Reference]" align:#left
			pickbutton InstanceRef "Instance Object" width:150 align:#left
		)

		on UI_Mesh rolledUp State do (resizeWindow ToolBoy State UI_Mesh)
		
		on ResetXforms pressed do
		(
			clearListener()
			print("Resetting Xforms!")

			local tempParents = #()
			local tempTransforms = #()		
			local tempArray = collectObjects 1

			with redraw off 
			(
				if (selection.count != 0) then
				(
					for j = 1 to 6 do
					(
						for i = 1 to tempArray.count do
						(
							local o = tempArray[i]
							
							case j of 
							(
								1:
								(
									--print("1...")
									
									append tempParents o.parent
									o.parent = undefined
									
									break
								)
								
								2:
								(
									--print("2...")
									
									tempDummy = Point Size:8
									tempDummy.rotation = in coordsys world o.rotation
									tempDummy.position = o.position

									--Don't over-rotate!
									--in coordsys local tempDummy.rotation.Y_rotation += 180
									
									tempDummy.name = ("point:" + o.name)
									
									append tempTransforms tempDummy 

									break
								)

								3:
								(
									--print("3...")

									ResetXform o
									collapseStack o
									convertTo o Editable_Poly 
									
									break
								)
					
								4:
								(
									--print("4...")

									RotatePivotOnly o tempTransforms[i].rotation
									o.transform = matrix3 1
									o.rotation = eulerangles 0 0 0
									
									o.rotation = tempTransforms[i].rotation
									o.position = tempTransforms[i].position
									
									break
								)
								
								5:
								(
									--print("5...")
									
									o.parent = tempParents[i]
									
									break
								)
								
								6:
								(
									--print("6...")
									
									if (tempTransforms[i] != undefined) do
									(
										delete tempTransforms[i]
									)
									
									break
								)
							)
						)					
					)
					
					print("Done with operation!")
				)
				else
				(
					clearListener()
					messageBox "Select something first, or use prefix!" title:"Select something!"
					print("Select something first, or use prefix!")
					return()
				)
			)
		)

		on RefreshSkinnedMesh pressed do
		(
			local MeshesToRefresh = #()
			
			for o in (selection as array) do
			(
				if (classOf o.modifiers[1] == Skin) do
				(
					if (isvalidnode o) do append MeshesToRefresh o
				)
			)
			
			for o in MeshesToRefresh do
			(
				print("Toggled " + o.name + "'s skin visibility")
				o.modifiers[1].enabled = false
				o.modifiers[1].enabled = true
			)
			
			free MeshesToRefresh
		)
		
		on RefreshInstances pressed do
		(
			try
			(
				disableSceneRedraw()
				
				local filterSelection = selection as array
								
				for i = 1 to filterSelection.count do
				(
					--if (o.name == matchPattern(storedName*)) do
					o = filterSelection[i]
					
					maxOps.cloneNodes InstanceRef.object cloneType:#instance newNodes:&newNode #nodialog
					
					newNode[1].parent = o.parent
					newNode[1].transform = o.transform
					
					--print("Replacing: " + o.name + " with ref: " + InstanceRef.object.name)
					
					delete o
				)
			)
			catch(enableSceneRedraw())
				
			enableSceneRedraw()
		)
		
		on InstanceRef picked newRef do
		(
			InstanceRef.text = newRef.name
		)
	)

	on ToolBoy open do
	(
		print("Hey, it's ToolBoy!")

		global rol_s = UI_Settings
		global rol_r = UI_Rigging
		global rol_m = UI_Mesh

		addSubRollout UI_Base rol_s
		addSubRollout UI_Base rol_r
		addSubRollout UI_Base rol_m

		rol_s.open = false
		rol_r.open = false
		rol_m.open = false
	)
	
)

try(destroyDialog ToolBoy)catch()
createDialog ToolBoy style:#(#style_toolwindow, #style_sysmenu) pos:[1100,200] width:190 height:70
)