--
-- (C) 2018 - ntop.org
--

local email = {}

email.EXPORT_FREQUENCY = 60

local function buildMessageHeader(now_ts, from, to, subject, body)
  local now = os.date("%a, %d %b %Y %X", now_ts) -- E.g. "Tue, 3 Apr 2018 14:58:00"
  local msg_id = "<" .. now_ts .. "." .. os.clock() .. "@ntopng>"

  local lines = {
    "From: " .. from,
    "To: " .. to,
    "Subject: " .. subject,
    "Date: " ..  now,
    "Message-ID: " .. msg_id,
    "Content-Type: text/html; charset=UTF-8",
  }

  return table.concat(lines, "\r\n") .. "\r\n\r\n" .. body .. "\r\n"
end

function email.sendEmail(subject, message_body)
  local smtp_server = ntop.getPref("ntopng.prefs.alerts.smtp_server")
  local from_addr = ntop.getPref("ntopng.prefs.alerts.email_sender")
  local to_addr = ntop.getPref("ntopng.prefs.alerts.email_recipient")

  if isEmptyString(from_addr) or isEmptyString(to_addr) or isEmptyString(smtp_server) then
    return false
  end

  local from = from_addr:gsub(".*<(.*)>", "%1")
  local to = to_addr:gsub(".*<(.*)>", "%1")
  local product = ntop.getInfo(false).product
  local info = ntop.getHostInformation()

  subject = product .. " [" .. info.instance_name .. "@" .. info.ip .. "] " .. subject

  if not string.find(smtp_server, "://") then
    smtp_server = "smtp://" .. smtp_server
  end

  local parts = string.split(to, "@")

  if #parts == 2 then
    local sender_domain = parts[2]
    smtp_server = smtp_server .. "/" .. sender_domain
  end

  local message = buildMessageHeader(os.time(), from_addr, to_addr, subject, message_body)
  return ntop.sendMail(from, to, message, smtp_server)
end

function email.sendNotifications(notifications)
  local subject = ""

  if #notifications > 1 then
    subject = "(" .. i18n("alert_messages.x_alerts", {num=#notifications}) .. ")"
  end

  local message_body = {}

  -- Multiple notifications
  for _, notif in ipairs(notifications) do
    message_body[#message_body + 1] = formatAlertNotification(notif, true)
  end

  message_body = table.concat(message_body, "<br>")

  return email.sendEmail(subject, message_body)
end

return email