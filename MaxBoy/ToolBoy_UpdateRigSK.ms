
rollout UpdateSK "Update SK" width:175
(
    include "MaxBoy_Functions.ms"
    --include "$userScripts\MaxBoy\MaxBoy_Functions.ms"

    group ""
    (
        button Setup "Setup" width:100 align:#center
    )

    group ""
    (
        label ui_label_ref "Reference" align:#left
        pickbutton ui_ref "< Old SK >" width:150 height:20 tooltip:"Reference root node"
        label ui_label_tar "Target" align:#left
        pickbutton ui_tar "< New SK >" width:150 height:20 tooltip:"Target root node"

        spinner ui_alignDepth "Align Depth" range:[0, 100, 2] type:#integer align:#left
        checkbox ui_applyPrefix "Apply Prefix" checked:true align:#left
    )

    on ui_ref picked obj do
    (
        if (obj != undefined) do
        (
            ui_ref.text = ("> " + obj.name + " <")
            ui_ref.object = obj
        )
    )

    on ui_tar picked obj do
    (
        if (obj != undefined) do
        (
            ui_tar.text = ("> " + obj.name + " <")
            ui_tar.object = obj
        )
    )

    on ui_ref rightclick do
    (
        ui_ref.text = "< Old SK >"
        ui_ref.object = undefined
    )

    on ui_tar rightclick do
    (
        ui_tar.text = "< New SK >"
        ui_tar.object = undefined
    )

    on Setup pressed do
    (
        local ObjA = ui_ref.object
        local ObjB = ui_tar.object

        if (ObjA == undefined or ObjB == undefined) do ( print("Undefined reference!") return() )

        local AlignDepth = ui_alignDepth.value
        local AlignDepthCount = 0

        local tempMesh = #()

        --Handle selected meshes (Select OLD)
        for m in selection do
        (
            for check in $* do
            (
                if ((MatchPattern check.name pattern:m.name) and (m != check)) do
                (
                    --Move new mesh to old mesh's layer
                    local mLayer = LayerManager.getLayerFromName m.layer.name
                    mLayer.addNode check

                    append tempMesh m
                )
            )
        )

        --Delete old meshes
        for i = 1 to tempMesh.count do
        (
            local mo = if (isValidNode tempMesh[i]) then tempMesh[i] else continue

            delete mo
        )


        local GroupA = GetChildren obj:ObjA
        local GroupB = GetChildren obj:ObjB

        --Store off a prefix to re-apply after replacement is done
        local pre = GetPrefix sel:GroupA

        StripPrefixes GroupA
        StripPrefixes GroupB

        SortToHierarchy &GroupA
        SortToHierarchy &GroupB

        --Align new rig to old with set depth
        TransferPose ParentA:GroupA[1] ParentB:GroupB[1] NameBased:true Depth:AlignDepth

        --Main operation
        for i = 1 to GroupA.count do
        (
            local rn = GroupA[i]
            local tn = GroupB[i]

            --Add target node to reference node's layer
            local rLayer = LayerManager.getLayerFromName rn.layer.name
            rLayer.addNode tn

            --Detect constraints and readjust related controllers before re-constraining with same methods
            local rPos = rn.position.controller
            local rRot = rn.rotation.controller

            --Transfer pos controllers
            case (ClassOf rPos) of
            (
                position_list:
                (
                    for c = 1 to rPos.count do
                    (
                        local con = rPos[c].object

                        if (con != undefined) do
                        (
                            if (ClassOf con == Position_Constraint) do
                            (
                                local ConstraintController = con.getNode 1

                                if (ConstraintController != undefined) do
                                (
                                    print(tn.name + " > Pos > " + ConstraintController.name)

                                    ConstraintController.transform.position = tn.transform.position
                                    tn.position.controller = rn.position.controller
                                )
                            )
                        )
                    )
                )

                Position_Constraint:
                (
                    local ConstraintController = rPos.getNode 1

                    if (ConstraintController != undefined) do
                    (
                        print(tn.name + " > Pos > " + ConstraintController.name)

                        ConstraintController.transform.position = tn.transform.position
                        tn.position.controller = rn.position.controller
                    )
                )

                Position_XYZ:
                (
                    --Not constrained, do nothing to this bone
                )
            )

            --Transfer rot controllers
            case (ClassOf rRot) of
            (
                rotation_list:
                (
                    for c = 1 to rRot.count do
                    (
                        local con = rRot[c].object

                        if (con != undefined) do
                        (
                            if (ClassOf con == Orientation_Constraint) do
                            (
                                local ConstraintController = con.getNode 1

                                if (ConstraintController != undefined) do
                                (
                                    print(tn.name + " > Rot > " + ConstraintController.name)

                                    ConstraintController.transform.rotation = tn.transform.rotation
                                    tn.rotation.controller = rn.rotation.controller
                                )
                            )
                        )
                    )
                )

                Orientation_Constraint:
                (
                    local ConstraintController = rRot.getNode 1

                    if (ConstraintController != undefined) do
                    (
                        print(tn.name + " > Rot > " + ConstraintController.name)

                        ConstraintController.transform.rotation = tn.transform.rotation
                        tn.rotation.controller = rn.rotation.controller
                    )
                )

                Euler_XYZ:
                (
                    --Not constrained, do nothing to this bone
                )
            )
        )

        --Delete old sk
        for obj in GroupA do
        (
            if (obj != undefined) do
            (
                delete obj
            )
        )

        --Add old prefix to new nodes
        if (pre.count != 0) do
        (
            for obj in GroupB do
            (
                if (obj != undefined) do
                (
                    obj.name = pre[1] + obj.name
                )
            )
        )
    )
)

createDialog UpdateSK
