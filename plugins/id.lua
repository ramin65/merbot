do

  local function send_group_members(extra, list)
    local msg = extra.msg
    local cmd = extra.cmd
    if cmd == 'pm' then
      send_api_msg(msg, msg.from.peer_id, list, true, 'html')
    elseif msg.text == '!id chat' then
      send_api_msg(msg, get_receiver_api(msg), list, true, 'html')
    end
  end

  local function resolve_user(extra, success, result)
    if success == 1 then
      if result.username then
        user_name = ' @'..result.username
      else
        user_name = ''
      end
      local msg = extra.msg
      local text = '<code>Name      :</code><b>'..(result.first_name or '')..' '..(result.last_name or '')..'</b>\n'
                 ..'<code>First name:</code>'..(result.first_name or '')..'\n'
                 ..'<code>Last name :</code>'..(result.last_name or '')..'\n'
                 ..'<code>User name :</code>'..user_name..'\n'
                 ..'<code>ID        :'..result.peer_id..'</code>'
      send_api_msg(msg, get_receiver_api(msg), text, true, 'html')
    else
      send_api_msg(msg, get_receiver_api(msg), '<b>Failed</b> to resolve <code>'
          ..extra.usr..'</code> IDs.\nCheck if <code>'..extra.usr..'</code> is correct.', true, 'html')
    end
  end

  local function scan_name(extra, success, result)
    local msg = extra.msg
    local uname = extra.uname
    if msg.to.peer_type == 'channel' then
      member_list = result
    else
      member_list = result.members
    end
    local founds = {}
    for k,member in pairs(member_list) do
      fields = {'first_name', 'last_name', 'print_name'}
      for k,field in pairs(fields) do
        if member[field] and type(member[field]) == 'string' then
          local gp_member = member[field]:lower()
          if gp_member:match(uname:lower()) then
            founds[tostring(member.id)] = member
          end
        end
      end
    end
    if next(founds) == nil then -- Empty table
      send_api_msg(msg, get_receiver_api(msg), uname..' <b>not found on this chat</b>', true, 'html')
    else
      local text = ''
      for k,user in pairs(founds) do
        if user.username then
          user_name = ' @'..user.username
        else
          user_name = ''
        end
        text = '<code>Name      :</code><b>'..(user.first_name or '')..' '..(user.last_name or '')..'</b>\n'
             ..'<code>First name:</code>'..(user.first_name or '')..'\n'
             ..'<code>Last name :</code>'..(user.last_name or '')..'\n'
             ..'<code>User name :</code>'..user_name..'\n'
             ..'<code>ID        :'..user.peer_id..'</code>\n\n'
      end
      send_api_msg(msg, get_receiver_api(msg), text, true, 'html')
    end
  end

  local function action_by_reply(extra, success, result)
    if result.from.username then
      user_name = ' @'..result.from.username
    else
      user_name = ''
    end
    local text = '<code>Name      :</code><b>'..(result.from.first_name or '')..' '..(result.from.last_name or '')..'</b>\n'
               ..'<code>First name:</code>'..(result.from.first_name or '')..'\n'
               ..'<code>Last name :</code>'..(result.from.last_name or '')..'\n'
               ..'<code>User name :</code>'..user_name..'\n'
               ..'<code>ID        :'..result.from.peer_id..'</code>'
    send_api_msg(extra, get_receiver_api(extra), text, true, 'html')
  end

  local function returnids(extra, success, result)
    local msg = extra.msg
    local cmd = extra.cmd

    if msg.to.peer_type == 'channel' then
      chat_id = msg.to.peer_id
      chat_title = msg.to.title
      member_list = result
    else
      chat_id = result.peer_id
      chat_title = result.title
      member_list = result.members
    end

    local list = '<b>'..chat_title..'</b> - <code>'..chat_id..'</code>\n\n'
    local text = chat_title..' - '..chat_id..'\n\n'

    i = 0
    for k,v in pairsByKeys(member_list) do
      i = i+1
      if v.username then
        user_name = ' @'..v.username
      else
        user_name = ''
      end
      list = list..'<b>'..i..'</b>. <code>'..v.peer_id..'</code> -'..user_name..' '..(v.first_name or '')..(v.last_name or '')..'\n'
      if #list > 2048 then
        send_group_members(extra, list)
        list = ''
      end
      text = text..i..'. '..v.peer_id..' -'..user_name..' '..(v.first_name or '')..(v.last_name or '')..'\n'
    end

    if cmd == 'txt' or cmd == 'pmtxt' then
      local textfile = '/tmp/chat_info_'..msg.to.peer_id..'_'..os.date("%y%m%d.%H%M%S")..'.txt'
      local file = io.open(textfile, 'w')
      file:write(text)
      file:flush()
      file:close()
      if cmd == 'txt' then
        send_document(get_receiver(msg), textfile, rmtmp_cb, {file_path=textfile})
      elseif cmd == 'pmtxt' then
        send_document('user#id'..msg.from.peer_id, textfile, rmtmp_cb, {file_path=textfile})
      end
    end
    send_group_members(extra, list)
  end

--------------------------------------------------------------------------------

  local function run(msg, matches)
	if matches[1] == 'me' then
	local hash = 'floodc:'..msg.from.peer_id..':'..msg.to.peer_id
	local msgs = redis:get(hash)
	local name = 'User : '
	local caption = name..' ['..msg.from.peer_id..']%0AYour messages conut in this group : '..msgs
	local url = 'https://api.telegram.org/bot'.._config.bot_api.key..'/getUserProfilePhotos?user_id='
	local res, code = https.request(url..msg.from.peer_id)
	local jdat = json:decode(res)
	local fileid = jdat.result.photos[1][3].file_id
	https.request('https://api.telegram.org/bot'.._config.bot_api.key..'/sendphoto?chat_id='..get_receiver_api(msg)..'&photo='..fileid..'&caption='..caption)
	end
    local gid = msg.to.peer_id
    local uid = msg.from.peer_id

    if not is_chat_msg(msg) and not is_admin(uid) then
      return nil
    end

    if is_mod(msg, gid, uid) then
      if matches[1] == 'id' and msg.reply_id then
        get_message(msg.reply_id, action_by_reply, msg)
      elseif matches[1] == 'chat' then
        if msg.to.peer_type == 'channel' then
          channel_get_users('channel#id'..gid, returnids, {msg=msg, cmd=matches[2]})
        end
        if msg.to.peer_type == 'chat' then
          chat_info('chat#id'..gid, returnids, {msg=msg, cmd=matches[2]})
        end
      elseif matches[1] == '@' then
        resolve_username(matches[2], resolve_user, {msg=msg, usr=matches[2]})
      elseif matches[1]:match('%d+$') then
        user_info('user#id'..matches[1], resolve_user, {msg=msg, usr=matches[1]})
      elseif matches[1] == 'name' then
        if msg.to.peer_type == 'channel' then
          channel_get_users('channel#id'..gid, scan_name, {msg=msg, uname=matches[2]})
        end
        if msg.to.peer_type == 'chat' then
          chat_info('chat#id'..gid, scan_name, {msg=msg, uname=matches[2]})
        end
      end
    end

    if matches[1] == 'id' and not msg.reply_id then
      if msg.from.username then
        user_name = '@'..msg.from.username
      else
        user_name = ''
      end
      local text = '<code>Name      :</code><b>'..(msg.from.first_name or '')..' '..(msg.from.last_name or '')..'</b>\n'
                 ..'<code>First name:</code>'..(msg.from.first_name or '')..'\n'
                 ..'<code>Last name :</code>'..(msg.from.last_name or '')..'\n'
                 ..'<code>User name :</code>'..user_name..'\n'
                 ..'<code>ID        :'..uid..'</code>'
      if not is_chat_msg(msg) then
        send_api_msg(msg, get_receiver_api(msg), text, true, 'html')
      else
        send_api_msg(msg, get_receiver_api(msg), text..'\n\nYou are in group <b>'..msg.to.title..'</b> [<code>'..gid..'</code>]', true, 'html')
      end
    end

  end

--------------------------------------------------------------------------------

  return {
    description = 'Know your id or the id of a chat members.',
    usage = {
      moderator = {
        '<code>!me</code>',
        'Return your information.',
        '<code>!id</code>',
        'Return ID of replied user if used by reply.',
        '<code>!id chat</code>',
        'Return the IDs of the current chat members.',
        '<code>!id chat txt</code>',
        'Return the IDs of the current chat members and send it as text file.',
        '<code>!id chat pm</code>',
        'Return the IDs of the current chat members and send it to PM.',
        '<code>!id chat pmtxt</code>',
        'Return the IDs of the current chat members, save it as text file and then send it to PM.',
        '<code>!id [user_id]</code>',
        'Return the IDs of the user_id.',
        '<code>!id @[user_name]</code>',
        'Return the member username ID from the current chat.',
        '<code>!id [name]</code>',
        'Search for users with name on <code>first_name</code>, <code>last_name</code>, or <code>print_name</code> on current chat.'
      },
      user = {
        '<code>!me</code>',
        'Return your information.',
        '<code>!id</code>',
        'Return your ID and the chat id if you are in one.'
      },
    },
    patterns = {
      '^[!/#](me)$',
      '^[!/#](id)$',
      '^[!/#]id (chat)$',
      '^[!/#]id (chat) (.+)$',
      '^[!/#]id (name) (.*)$',
      '^[!/#]id (@)(.+)$',
      '^[!/#]id (%d+)$',
    },
    run = run
  }

end
