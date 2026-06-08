


Function NetworkDiscoveryPlugin_Initialize(msgPort As Object, userVariables As Object, bsp As Object) As Object
    
    
    h = {}
    h.msgPort = msgPort
    h.userVariables = userVariables
    h.bsp = bsp
    h.systemLog = CreateObject("roSystemLog")
    h.ProcessEvent = NetworkDiscoveryPlugin_ProcessEvent
    
    ' Create a dedicated message port just for discovery tracking
    h.discoveryPort = CreateObject("roMessagePort")
    h.discovery = CreateObject("roNetworkDiscovery")
    
    if h.discovery <> invalid then
        h.discovery.SetPort(h.discoveryPort)
    else
        h.systemLog.SendLine("------------ NetworkDiscoveryPlugin: ERROR - roNetworkDiscovery is not supported on this firmware version.")
        return invalid
    end if
    
    ' Create a recurring system timer to safely check the background discovery port
    h.timer = CreateObject("roTimer")
    h.timer.SetPort(msgPort) ' Hooked to main port to trigger ProcessEvent safely
    
    ' Check the background queue every 1 second (1 second, 0 microseconds)
    h.timer.SetElapsed(1, 0) 
    h.timer.Start()
    
    ' Search parameters:
    searchCriteria = { 
        type: "_http._tcp",
        protocol: "IPv4" ' <-- Strictly forces the discovery layer to only listen for IPv4
    }
    
    if h.discovery.Search(searchCriteria) then
        h.systemLog.SendLine("------------ NetworkDiscoveryPlugin: mDNS scan successfully initiated.")
    else
        h.systemLog.SendLine("------------ NetworkDiscoveryPlugin: ERROR - Failed to start search.")
    end if
    
    return h
End Function


Function NetworkDiscoveryPlugin_ProcessEvent(event As Object) As Boolean
    retval = false 
    
    if type(event) = "roTimerEvent" then
        
        msg = m.discoveryPort.GetMessage()

        while msg <> invalid
            msgType = type(msg)
            
            ' Case A: A player has been successfully found and resolved
            if msgType = "roNetworkDiscoveryResolvedEvent" then

                ' Extract the payload data dictionary
                data = msg.GetData()
                if data <> invalid then

                    'if type(data) = "roAssociativeArray" then
                        'm.systemLog.SendLine("------------------------ " + FormatJson(data))
                        '{"address":"192.168.1.145","domain":"local","host_name":"BrightSign-USD39X001946.local","name":"BRIGHTSIGN-LWS-SERVICE","protocol":"IPv4","txt":{"functionality":"content","serialnumber":"USD39X001946","unitdescription":"Sherwood","unitname":"XT1145 (145)","unitnamingmethod":"unitNameOnly"},"type":"_http._tcp"}
                    'end if
       
                    m.systemLog.SendLine("------------------ NetworkDiscoveryPlugin: Player Found!")
                    m.systemLog.SendLine("----- Name:       " + data["name"])

                    if (left(data["name"], 10) = "BRIGHTSIGN") then
                        m.systemLog.SendLine("----- IP Address: " + data["address"])

                        if data["txt"]["serialnumber"] <> invalid then
                            m.systemLog.SendLine("----- Serial:     " + data["txt"]["serialnumber"])
                        end if
                        if data["txt"]["unitname"] <> invalid then
                            m.systemLog.SendLine("----- Unit Name:  " + data["txt"]["unitname"])
                        end if
                        m.systemLog.SendLine("----- Hostname:   " + data["host_name"])
                    end if

                end if
                retval = true
                
            ' Case B: The search run completed naturally
            else if msgType = "roNetworkDiscoveryCompletedEvent" then
                m.systemLog.SendLine("------------------ NetworkDiscoveryPlugin: Search sequence completed.")
               
                retval = true
            ' Case C: Uncommon general notification
            else if msgType = "roNetworkDiscoveryGeneralEvent" then
                m.systemLog.SendLine("------------------ NetworkDiscoveryPlugin: General network discovery event received.")
                retval = true

            end if
            
            ' Fetch next message in queue if available
            msg = m.discoveryPort.GetMessage()
        end while
        
        ' RESTART TIMER: if you need repeated checks uncomment the line below.
        ' m.timer.Start()
        ' Otherwise, the plugin will only process discovery events that arrive within the first 1 second.

    end if
    
    return retval
End Function