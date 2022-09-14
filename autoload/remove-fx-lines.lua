script_name = "还原卡拉OK模板行"
script_description = "移除fx行并将karaoke行取消注释"
script_author = "ProjectXero"
script_version = "0.0.1"

function macro_remove_fx(subs)
	local i = 1
	while i <= #subs do
		aegisub.progress.set((i-1) / #subs * 100)
		local l = subs[i]
		if l.class == "dialogue" and l.comment and l.effect == "karaoke" then
			l.comment = false
			l.effect = ""
			subs[i] = l
		elseif l.class == "dialogue" and l.effect == "fx" then
			subs.delete(i)
			i = i - 1
		end
		i = i + 1
	end
	aegisub.set_undo_point("remove fx lines")
end

aegisub.register_macro("还原卡拉OK模板行", "移除fx行并将karaoke行取消注释", macro_remove_fx)