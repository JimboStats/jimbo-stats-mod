--- STEAMODDED HEADER
--- MOD_NAME: Jimbo Stats
--- MOD_ID: JimboStats
--- MOD_AUTHOR: [demarcot, AxBolduc, mwithington]
--- MOD_DESCRIPTION: Tracks stats for balatro runs

----------------------------------------------
------------MOD CODE -------------------------
--
local game_start_run_ref = Game.start_run
function Game:start_run(args)
	local fromRef = game_start_run_ref(self, args)
	G.GAME.data_sent = false
end

local game_update_game_over_ref = Game.update_game_over
function Game:update_game_over(dt)
	local fromRef = game_update_game_over_ref(self, dt)

	if not G.GAME.data_sent then
		local ante = G.GAME.round_resets.ante
		local won = ante > G.GAME.win_ante
		local round = G.GAME.round
		local seed = G.GAME.pseudorandom.seed

		-- lost to
		local blind_choice = { config = G.GAME.blind.config.blind or G.P_BLINDS.bl_small }
		local lost_to = localize({ type = "name_text", key = blind_choice.config.key, set = "Blind" })

		local cards_played = G.GAME.round_scores["cards_played"].amt
		local cards_discarded = G.GAME.round_scores["cards_discarded"].amt
		local cards_purchased = G.GAME.round_scores["cards_purchased"].amt
		local times_rerolled = G.GAME.round_scores["times_rerolled"].amt
		local new_collection = G.GAME.round_scores["new_collection"].amt
		local best_hand = number_format(G.GAME.round_scores["hand"].amt)
		local most_played_hand = GetMostPlayedHand()

		-- Anything here comes after the game ends
		local gameStats = {
			bestHand = best_hand,
			mostPlayedHand = most_played_hand,
			cardsPlayed = cards_played,
			cardsDiscarded = cards_discarded,
			cardsPurchased = cards_purchased,
			timesRerolled = times_rerolled,
			newDiscoveries = new_collection,
			won = won,
			seed = seed,
			ante = ante,
			round = round,
			lostTo = lost_to,
		}
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			delay = 0,
			blocking = false,
			func = function()
				request("http://localhost:3000/api/v1/runs", { body = gameStats })
				return true
			end,
		}))
		G.GAME.data_sent = true
	end
end

function GetMostPlayedHand()
	local handname, amount = localize("k_none"), 0
	for k, v in pairs(G.GAME.hand_usage) do
		if v.count > amount then
			handname = v.order
			amount = v.count
		end
	end

	return localize(handname, "poker_hands")
end

function requestOnThread(url, data)
	local http_thread = love.thread.newThread([[
      local https = require("socket.http")
      local ltn12 = require("ltn12")
			CHANNEL = love.thread.getChannel("stats_channel")

			while true do
				--Monitor the channel for any new requests
				local request = CHANNEL:demand()
				if request then
          local response = {}
          local headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#request.data),
                ["api-key"] = request.apiKey,
              }

          local r, c, h, s = https.request({
                url = request.url,
                method = "POST",
                headers = headers,
                source = ltn12.source.string(request.data),
                sink = ltn12.sink.table(response),
              })
        end
			end
		]])
	local http_channel = love.thread.getChannel("stats_channel")
	http_thread:start()

	local request = {
		url = url,
		data = data,
		apiKey = G.SETTINGS.jimboStatsApiKey or "",
	}

	http_channel:push(request)
end

function request(url, options)
	if options.method == "POST" and not options.body then
		sendDebugMessage("sending POST request with empty body...")
		return
	end

	local data = json.encode(options.body)
	sendDebugMessage(data)
	requestOnThread(url, data)
end

-- API Key stuff here

function G.FUNCS.balatro_stats_api_key(event)
	G.SETTINGS.paused = true

	G.FUNCS.overlay_menu({
		definition = create_api_key_input(event),
	})
end

local create_UIBox_main_menu_buttonsRef = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
	local modsButton = UIBox_button({
		id = "balatro_stats_api_key",
		minh = 1.55,
		minw = 1.85,
		col = true,
		button = "balatro_stats_api_key",
		colour = G.C.PINK,
		label = { "Stats" },
		scale = 0.45 * 1.2,
	})
	local menu = create_UIBox_main_menu_buttonsRef()
	table.insert(menu.nodes[1].nodes[1].nodes, #menu.nodes[1].nodes[1].nodes + 1, modsButton)
	menu.nodes[1].nodes[1].config =
		{ align = "cm", padding = 0.15, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK, mid = true }
	return menu
end

G.JIMBO_STATS = {}
G.JIMBO_STATS.ref_table = {
	api_key_text = G.SETTINGS.jimboStatsApiKey or "",
}

function create_api_key_input(event)
	return (
		create_UIBox_generic_options({
			back_func = "exit_overlay_menu",
			contents = {
				{
					n = G.UIT.R,
					config = {
						padding = 0,
						align = "tm",
					},
					nodes = {
						create_text_input({
							prompt_text = "API key",
							extended_corpus = true,
							ref_table = G.JIMBO_STATS.ref_table,
							max_length = 64,
							ref_value = "api_key_text",
							text_scale = 0.3,
							w = 5,
							h = 0.6,
						}),
						UIBox_button({
							label = {
								"Paste",
								"API Key",
							},
							minw = 1,
							minh = 0.6,
							button = "paste_api_key",
							colour = G.C.BLUE,
							scale = 0.3,
							col = true,
						}),
						UIBox_button({
							label = {
								"Save",
								"API Key",
							},
							minw = 1,
							minh = 0.6,
							button = "save_api_key",
							colour = G.C.GREEN,
							scale = 0.3,
							col = true,
						}),
					},
				},
			},
		})
	)
end

G.FUNCS.paste_api_key = function(e)
	G.CONTROLLER.text_input_hook = e.UIBox:get_UIE_by_ID("text_input").children[1].children[1]
	for i = 1, 8 do
		G.FUNCS.text_input_key({ key = "left" })
	end
	for i = 1, 8 do
		G.FUNCS.text_input_key({ key = "backspace" })
	end
	local clipboard = (G.F_LOCAL_CLIPBOARD and G.CLIPBOARD or love.system.getClipboardText()) or ""
	for i = 1, #clipboard do
		local c = clipboard:sub(i, i)
		G.FUNCS.text_input_key({ key = c })
	end
	G.FUNCS.text_input_key({ key = "return" })
end

G.FUNCS.save_api_key = function(e)
	G.SETTINGS.jimboStatsApiKey = G.JIMBO_STATS.ref_table.api_key_text
	G:save_settings()
	G.FILE_HANDLER.force = true
end

-- End API Key stuff

