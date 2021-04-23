/*/////////////////////////////////////////
Toolboy is a collection of neatly packed
macros and tools to speed up general tasks.
/////////////////////////////////////////*/

--Start ToolBoy--
(
include "$userScripts\MaxBoy\MaxBoy_Functions.ms"

global PipeBoy_FloaterWindowHeight --Height of floater

rollout ToolBoy "ToolBoy"
(
	--Global settings
	global s_cPrefix = "c_"
	global s_print = false

	global PrintToConsole = false

	--Global arrays
	global nodeList = #()

	subRollout UI_Base width:190 height:70 pos:[-1,-1]

	--Window resize function for rollouts [ Override ]
	fn ResizeFloaterWindow ro =
	(
		try
		(
			local fold = if (ro.open) then 1 else -1

			UI_Base.height += ro.height * fold
			ToolBoy.height += ro.height * fold
	    )
	    catch
	    (
	    	print("ResizeFloaterWindow :: Rollout folding error! Rollout >> " + (ro as string))
	    	throw()
	    )
	)

	rollout UI_Settings "General"
	(
		group "Misc"
		(
		    button ui_Button_GiveDummies "Give Dummies" width:150 align:#left toolTip:"Add dummy object at selected object(s) transforms."

		    multiListBox ui_DummyType "Type" items:#("Cross", "Box", "Axis Tripod", "Center Marker") selection:#(1) height:4
		    checkbox ui_DummyInhParent "Inherit parent"
		    checkbox ui_DummyInhScale "Inherit scale"
		    spinner ui_DummyScale "Size" range:[0,1000,10] width:100 align:#left
		)

		group "Transform"
		(
			button ui_Button_ResetXforms "Reset Xforms" width:150 align:#left
			button ui_Button_ResetScales "Reset Scales" width:150 align:#left
		)

		--Handle window scaling when rolled up
		on UI_Settings rolledUp State do (ResizeFloaterWindow UI_Settings)

		on ui_Button_GiveDummies pressed do
		(
			--clearListener()

			if (selection.count == 0) do
			(
				messageBox "Nothing selected, quitting." title:"Error!"
				return()
			)

			with undo off
			(
				with redraw off
				(
					--Sort arrays to align with hierarchy indexes
					local tempArray = (selection as array)

					if (tempArray == undefined) do (return())

					--Copy nodes to make controllers for
					local nodeCopies = CopyNodes collection:tempArray

					--Sort controller array to make isolating the parents easier
					SortToHierarchy &nodeCopies

					--Create local node to parent controllers to
					local nodeParent = Point Size:20 name:"PointParent" box:true cross:true

					for i = 1 to nodeCopies.count do
					(
						--If parent isn't amongst the copies, parent to dummy parent
						local localParent = findItem nodeCopies nodeCopies[i].parent

						--If I'm at the top or have no other parent amongst the copies, copy to dummy
						if (i == 1 or localParent == undefined) do
						(
							nodeCopies[i].parent = nodeParent
						)
					)

					local pointArray = #()

					--Dummy creation
					for i = 1 to nodeCopies.count do
					(
						local o = nodeCopies[i]

						if (o != undefined) then
						(
							if (ui_DummyInhScale.state == true) then
							(
								ps = GetRelativeScale(o) / 2
							)
							else
							(
								ps = ui_DummyScale.value
							)

							p = Point Size: (ps)
							p.transform = o.transform
							p.scale = [1,1,1]
							p.name = ("point:" + o.name)

							p.wirecolor = o.wirecolor

							p.cross = ui_DummyType.selection[1]
							p.box = ui_DummyType.selection[2]
							p.centermarker = ui_DummyType.selection[3]
							p.axistripod = ui_DummyType.selection[4]

							if (ui_DummyInhParent.checked == true) then
							(
								p.parent = o.parent

								for tChild in o.children do (tChild.parent = p)
							)
							else
							(
								p.parent = undefined
							)

							append pointArray p
						)
					)

					if (ui_DummyInhParent.checked == false) do (delete nodeParent)

					--Delete hierarchy reference objects
					for obj in nodeCopies do (delete obj)
				)
			)
		)

		on ui_Button_ResetXforms pressed do
		(
			clearListener()
			print("Resetting Xforms!")

			local tempParents = #()
			local tempTransforms = #()
			local tempArray = selection as array

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

		on ui_Button_ResetScales pressed do
		(
			--Moved to generic function for multi-usage
			local scaleArray = (selection as array)

			ResetScales(scaleArray)
		)
	)

	rollout UI_Rigging "Rigging"
	(
		local uiOffset = 180

		group "Controllers"
		(
			button bAddControllers "Add Controllers" width:150 align:#left
			--checkbox BoneMode "Bone mode" checked:true toolTip:"Use this for prefix-based auto-renaming on generated controllers."
			checkbox OrientToChild "Orient towards child" checked:true toolTip:"Should the controller point towards the next child or be oriented like the reference bone?"

			edittext cPrefix "Prefix:" text:"cnt_" width:125 toolTip:"Apply this prefix to generated controllers"

			dropdownlist CntrlType "Shape" items:#("Circle", "Box") selection:2
			checkbox CntrlInhScale "Inherit scale" toolTip:"Scales the controller's width based on the objects bounding box."
			spinner CntrlScale "Radius" range:[0,1000,4] width:100 align:#left
		)

		group "Constraints"
		(
			button bAddConstraints "Add Constraints" width:150 align:#left toolTip:"Add constraints based on proximity-based binding, for selected object(s)."

			checkbox AddPosition "Position Constraint" checked:true toolTip:"Add position constraint."
			checkbox AddOrientation "Rotation Constraint" checked:true toolTip:"Add rotation constraint."
			checkbox OrientationRelative "Relative Orientation" checked:true toolTip:"Should the rotation constraint be relative or absolute"

			pickButton ConstraintTarget "Target Root" pos:[14, uiOffset + 112]
			edittext ctTarget "" text:"none" pos:[90, uiOffset + 114] fieldWidth:70 height:20 readOnly:true
		)

		group "Motion Controllers"
		(
			button RegularController "Reset Controllers" width:150 align:#left
			button XrefController "Xref Controllers" width:150 align:#left tooltip:"Makes animation controllers into XRef controllers"
		)

		--Handle window scaling when rolled up
		on UI_Rigging rolledUp State do (ResizeFloaterWindow UI_Rigging)

		on ConstraintTarget picked newTarget do
		(
			--Update constraint target text
			ctTarget.text = newTarget.name
		)

		on cPrefix changed newPrefix do
		(
			--Update global setting
			s_cPrefix = newPrefix
			--print("Set new controller prefix to: " + (newPrefix as string))
		)

		on bAddControllers pressed  do
		(
			clearListener()
			print("Generating controllers!")

			disableSceneRedraw()

			with undo off
			(
				local collectionArray = selection as array

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

				StripPrefixes &collectionArray

				--Copy nodes to make controllers for
				local controllerCopies = CopyNodes collection:collectionArray

				--Sort controller array to make isolating the parents easier
				SortToHierarchy &controllerCopies

				--Create local node to parent controllers to
				local cntrlParent = Point Size:20 name:"CntrlParent"

				for i = 1 to controllerCopies.count do
				(
					--If parent isn't amongst the copies, parent to dummy parent
					local localParent = findItem controllerCopies controllerCopies[i].parent

					--If I'm at the top or have no other parent amongst the copies, copy to dummy
					if (i == 1 or localParent == undefined) do
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

							if (CntrlInhScale.checked == true) then
							(
								rad = GetRelativeScale(o) / 3
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
							local b_width = CntrlScale.value

							if (c == undefined) then
							(
								b_height = GetRelativeScale(o) / 1
							)
							else
							(
								b_height = distance o c
							)

							if (CntrlInhScale.checked == true) do
							(
								b_width = 2 + (b_height / 8)
							)

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

						cnt.wirecolor = o.wirecolor
						cnt.parent = o.parent

						for tChild in o.children do (tChild.parent = cnt)

						append controllerArray cnt

						--Rename to controller name
						cnt.name = (s_cPrefix + o.name)

						--Lock move axis by default
						setTransformLockFlags cnt #{1..3}
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

			enableSceneRedraw()

			gc()
		)

		on bAddConstraints pressed  do
		(
			--Get object selection for action
			local _BoneArray = #()
			local _ControllerArray = #()

			if (IsValidNode ConstraintTarget.object == false) do
			(
				messageBox "Target root object is undefined or has bad node! Re-pick the root node and try again." title:"Error"
				ConstraintTarget.object = undefined
				ctTarget.text = "!Bad Node!"
				return()
			)

			if (selection.count != 0) then
			(
				_ControllerArray = (selection as array)
				_BoneArray = GetChildren obj:ConstraintTarget.object
			)
			else
			(
				messageBox "No selection, exiting." title:"Error!"
				return()
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

		on RegularController pressed do
		(
			clearListener()
			print("Starting operation!")

			with redraw off
			(
				local tempArray = (selection as array)

				if (tempArray == undefined or tempArray.count == 0) do (return())

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
				local tempArray = selection as array

				if (tempArray == undefined) do (return())

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
	)

	rollout UI_Functions "Functions"
	(
		group "Instancing"
		(
			button ui_RefreshInstances "Refresh Instances" width:150 align:#left
			label ui_InstanceRef_Label "Instance Reference" align:#left
			pickbutton ui_InstanceRef "[ Instance Object ]" width:150 align:#left
		)

		group ""
		(
			button ui_SelectChildren "Select children" width:150
			button ui_AnimBaker "Anim Baker" width:150
			button ui_UpdateSK "Update SK" width:150
		)

		group "System"
		(
			button ui_CleanMem "Clean Mem" width:150 align:#left toolTip:"Clears scene memory caches"
			--button ui_NodeCheckup "Checkup!" width:150 align:#left toolTip:"Return bad transforms and other data"
		)

		on UI_Functions rolledUp State do (ResizeFloaterWindow UI_Functions)

		on ui_InstanceRef picked newRef do
		(
			ui_InstanceRef.text = newRef.name
		)

		on ui_SelectChildren pressed do
		(
			if selection.count == 1 then
			(
				selectionArray = #($)

				select(GetChildren obj:selection[1])

				join selectionArray selection

				select selectionArray
				Free selectionArray
			)
			else
			(
				messageBox "Multiple or no nodes are not supported!" title:"Error..."
			)
		)

		on ui_AnimBaker pressed do
		(
			try
			(
				local animBakerPath = ((pathConfig.GetDir #userScripts) + ( "\\MaxBoy\\ToolBoy_AnimBaker.ms")) as string
				fileIN animBakerPath
			)
			catch
			(
				MessageBox "Unable to find script file! Try reinstalling suite!" title:"External script error"
			)
		)

		on ui_UpdateSK pressed do
		(
			try
			(
				local animBakerPath = ((pathConfig.GetDir #userScripts) + ( "\\MaxBoy\\ToolBoy_UpdateRigSK.ms")) as string
				fileIN animBakerPath
			)
			catch
			(
				MessageBox "Unable to find script file! Try reinstalling suite!" title:"External script error"
			)
		)

		on ui_NodeCheckup pressed do
		(
			local aNodes = #() --All nodes
			local bNodes = #() --Bad nodes

			local r_badScale = false --Has bad scale?

			--Do initial bone rig check

			if (selection.count == 0) then
			(
				local RootNodes = GetRootNodes()

				if (ClassOf(RootNodes) != Array) do (RootNodes = #(RootNodes))

				for r in RootNodes do
				(
					join aNodes (GetChildren obj:r)
				)
			)
			else
			(
				aNodes = selection as array
			)

			for o in aNodes do
			(
				--Check scale (should be [1,1,1] for proper use)
				if (o.scale.x != 1.0 or o.scale.y != 1.0 or o.scale.z != 1.0) do
				(
					append bNodes o
					r_badScale = true
				)
			)

			if (r_badScale) then
			(
				rollout FixupDialogue "Fixup" width:380 height:350
				(
					local bn = #()

					label ui_BadScales "[Bad scale nodes]" align:#left
					MultiListBox ui_BadScales_Nodes "Nodes" width:225 height:15 pos:[15,40]
					--MultiListBox ui_BadScales_Scales "Scales" width:165 height:15 pos:[200,40]

					button ui_Button_OK "OK" pos:[145,300] width:100 align:#center
					button ui_Button_Fix "Fix" pos:[90,275] width:100 align:#center
					button ui_Button_FixAll "Fix All" pos:[200,275] width:100 align:#center

					button ui_Button_Refresh "Refresh" pos:[145,300] width:100 align:#center

					on ui_BadScales_Nodes selectionEnd do
					(
						ClearSelection()

						for s in ui_BadScales_Nodes.selection do
						(
							local selectedNode = getnodebyname ui_BadScales_Nodes.items[s]

							if (selectedNode != undefined) do ( selectmore selectedNode )
						)
					)

					on ui_Button_OK pressed do
					(
						--Close dialogue window with button
						DestroyDialog FixupDialogue
					)

					on ui_Button_Fix pressed do
					(
						local sel = ui_BadScales_Nodes.selection
						if sel.isEmpty do (return())
						sel = sel as array

						local selectedNodes = #()

						for i = 1 to sel.count do
						(
							local n = sel[i]
							append selectedNodes bn[n]
						)

						if (selectedNodes.count > 0) do (ResetScales(selectedNodes))

						--ui_BadScales_Scales.items = (for o in bn collect (o.scale as string))
					)

					on ui_Button_FixAll pressed do
					(
						ResetScales(bn)

						--ui_BadScales_Scales.items = (for o in bn collect (o.scale as string))
					)
				)

				CreateDialog FixupDialogue
				--Has to be placed after rollout creation!
				Join FixupDialogue.bn bNodes

				FixupDialogue.ui_BadScales_Nodes.items = (for o in bNodes collect o.name)
				--FixupDialogue.ui_BadScales_Nodes.items = (for o in bNodes collect (o.name + " :: " + (o.scale as string)))
				--FixupDialogue.ui_BadScales_Scales.items = (for o in bNodes collect (o.scale as string))
			)
			else
			(
				print("Everything checks out!")
			)
		)

		on ui_CleanMem pressed do
		(
			gc()
			freescenebitmaps()
			clearundobuffer()

			print("Cleared cached data!")
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

		on ui_RefreshInstances pressed do
		(
			try
			(
				disableSceneRedraw()

				local filterSelection = selection as array

				for i = 1 to filterSelection.count do
				(
					--if (o.name == matchPattern(storedName*)) do
					o = filterSelection[i]

					maxOps.cloneNodes ui_InstanceRef.object cloneType:#instance newNodes:&newNode #nodialog

					newNode[1].parent = o.parent
					newNode[1].transform = o.transform

					--print("Replacing: " + o.name + " with ref: " + ui_InstanceRef.object.name)

					delete o
				)
			)
			catch(enableSceneRedraw())

			enableSceneRedraw()
		)
	)

	on ToolBoy open do
	(
		print("Hey, it's ToolBoy!")

		global rol_s = UI_Settings
		global rol_r = UI_Rigging
		global rol_f = UI_Functions

		addSubRollout UI_Base rol_s
		addSubRollout UI_Base rol_r
		addSubRollout UI_Base rol_f

		ToolBoy_FloaterWindowHeight = (rol_s.height + rol_r.height + rol_f.height) + 77

		ToolBoy.height = ToolBoy_FloaterWindowHeight
		UI_Base.height = ToolBoy.height

		rol_s.open = true
		rol_r.open = false
		rol_f.open = false
	)
)

try(destroyDialog ToolBoy)catch()
createDialog ToolBoy style:#(#style_toolwindow, #style_sysmenu) pos:[1100,200] width:190 height:500
)

