-- Trigger Me Timbers Support

function onInit()
	if DeckedOutTriggers.isTriggerMeTimbersLoaded() then
		initializeTriggers()
		initializeConditions()
		initializeActions()
	end
end

function initializeTriggers()
	TriggerManager.defineEvent({
		sName = "cards_tmt_event_played",
		aParameters = {
			"sCardNode",
			"bFacedown",
			"bDiscard",
		}
	});

	-- This could be an issue, discarding hands will fire this for every card
	TriggerManager.defineEvent({
		sName = "cards_tmt_event_discarded", 
		aParameters = {
			"sCardNode",
			"bFacedown",
		}
	});
	
	-- Might need to change sGiverIdentity and sReceiverIdentity to rSource and rTarget so that
	-- it works with actions that use source and target. But that doesn't work with GM.
	TriggerManager.defineEvent({
		sName = "cards_tmt_event_given",
		aParameters = {
			"sCardNode",
			"sGiverIdentity",
			"sReceiverIdentity",
			"bFacedown"
		}
	})
end

function initializeConditions()
	TriggerManager.defineCondition({
		sName = "cards_tmt_condition_facedown",
		fCondition = isCardFacedown,
		aRequiredParameters = {
			"sCardNode",
			"bFacedown"
		},
		aConfigurableParameters = {
			{
				sName = "sFacedown",
				sDisplay = "cards_tmt_value",
				sType = "combo",
				aDefinedValues = {
					"cards_tmt_yes",
					"cards_tmt_no"
				}
			}
		}
	});
	TriggerManager.defineCondition({
		sName = "cards_tmt_condition_discard",
		fCondition = isCardDiscarded,
		aRequiredParameters = {
			"sCardNode",
			"bDiscard"
		},
		aConfigurableParameters = {
			{
				sName = "sDiscarded",
				sDisplay = "cards_tmt_value",
				sType = "combo",
				aDefinedValues = {
					"cards_tmt_yes",
					"cards_tmt_no"
				}
			}
		}
	});
end

function initializeActions()
end

function isTriggerMeTimbersLoaded()
	return TriggerManager ~= nil;
end

function fireEvent(sName, rEventData)
	if DeckedOutTriggers.isTriggerMeTimbersLoaded() then
		TriggerManager.fireEvent(sName, rEventData)
	end
end

function isCardFacedown(rTriggerData, rEventData)
	if rTriggerData.sFacedown == "cards_tmt_yes" then
		return rEventData.bFacedown == "true";
	end
	return rEventData.bFacedown == "false";
end

function isCardDiscarded(rTriggerData, rEventData)
	if rTriggerData.sFacedown == "cards_tmt_yes" then
		return rEventData.bDiscard == "true";
	end
	return rEventData.bDiscard == "false";
end