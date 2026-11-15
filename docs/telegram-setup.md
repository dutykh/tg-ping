<!--
  Telegram setup guide for tg-ping.

  Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
          Science and Technology, Abu Dhabi, UAE).
-->

# Setting up the Telegram side

Everything here happens once. The result is a bot token and a chat id, which
are the only two things `tg-ping` needs.

## Why a bot

Telegram does not let a program act as you. Instead you create a bot: a second
account that you own, which can write to you and to any group or channel you
add it to. The machine gets the bot's token, never your credentials, and you
can revoke that token at any time without touching your own account.

A bot cannot start a conversation. Somebody has to write to it first, which is
why the `/start` step below is not optional.

## Creating the bot

1. Open Telegram and search for `@BotFather`, the official bot that manages
   bots. Start a chat with it.
2. Send `/newbot`.
3. Give a display name, for example `Denys research alerts`. This is what you
   will see at the top of the chat.
4. Give a username. It must be unique across Telegram and end in `bot`, for
   example `dutykh_research_alerts_bot`.
5. BotFather answers with a token of the form
   `123456789:AAExampleTokenWithLettersAndDigits`. Copy it somewhere safe.

Useful follow up commands in the same chat with BotFather:

```text
/setdescription    text shown before the first message
/setuserpic        an avatar, which makes the chat easy to spot
/setcommands       a command list, if you ever add interaction
/revoke            invalidate the token and get a fresh one
/deletebot         remove the bot entirely
```

## Finding your chat id

Open the chat with your new bot and send it anything, `/start` for instance.
Then let the wizard do the rest:

```bash
tg-ping init
```

It validates the token, lists every chat that has written to the bot, asks
which one to use, asks what this machine should be called in messages, writes
`~/.config/tg-ping/default.env` with mode 600, and sends a confirmation
message. The token is typed without echo and never printed afterwards.

To do the same by hand:

```bash
export TG_PING_TOKEN=123456789:AAExampleTokenWithLettersAndDigits
tg-ping chats
```

Without `tg-ping` at all, the raw API answers the same question:

```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" |
    grep -o '"chat":{"id":[-0-9]*'
```

Telegram keeps unread updates for 24 hours only, so send a fresh message if
nothing shows up.

## Groups

1. Create the group, or open an existing one.
2. Add the bot as a member.
3. Post one message in the group.
4. Run `tg-ping chats`. Group ids are negative, for example `-987654321`.
   Supergroups look like `-1001234567890`.

Telegram runs bots in groups with **privacy mode** on: a bot only sees messages
that mention it or reply to it. That affects reading, not writing, so alerts
still arrive. If you want `tg-ping chats` to discover the group, either address
the bot in the message or send `/setprivacy` to BotFather and disable it.

## Channels

1. Add the bot to the channel as an administrator.
2. Give it permission to post messages.
3. Use the numeric id, or `@channel_name` for a public channel.

A channel is convenient when several people should read the alerts but only the
machine writes.

## Forum topics

A supergroup with topics enabled can hold one thread per project. Send the
topic id with every message:

```bash
tg-ping --topic 42 "the mesh generator finished"
export TG_PING_THREAD_ID=42
```

The id appears in the link to the topic, as the number after the group id.

## Topics in the chat with your bot

Telegram also allows topics inside the private chat with a bot, made by the bot
itself. With them, each project keeps its own thread on the phone, one per
computer, named like `heat-equation · laptop`, instead of one long mixed stream.

Topic mode belongs to the bot and is switched on once: in `@BotFather`, open
the settings of your bot (`/mybots`, then the bot) and turn on **Threaded
Mode**. Then check that Telegram reports it:

```bash
tg-ping doctor            # the "topics" line says whether topic mode is on
tg-ping config set topics project
```

From then on every message goes to the topic of its project and its machine.
The topic is made the first time the project sends something, made again if
you delete it, and while topics cannot be used (topic mode off, or Telegram
refusing them) messages go to the main chat, so nothing is lost. A message
given its own `--topic` keeps it.

## Several computers, one bot

One bot can serve every computer you own, and that is the simplest setup: the
same token and chat on each machine, and a different name for each, which then
appears on every message ("✅ 💻 laptop · Tests green").

```bash
tg-ping init                                  # on each machine, same token
tg-ping config set machine "office desktop"   # or name it later
```

The icon follows the kind of machine (💻 laptop, 🖥️ desktop, 🌐 server or
virtual machine), detected once when the name is set. Questions asked from
several computers at the same time are safe: each machine files the answers it
reads for the question they belong to, and leaves those of the other machines
for them to collect.

## Several bots

One bot per purpose keeps the chats readable, for instance one for the cluster
and one for personal work:

```bash
tg-ping init --profile cluster
tg-ping init --profile personal
tg-ping --profile cluster --ok "the queue is empty"
```

Each profile lives in its own file under `~/.config/tg-ping/`. A project can
choose its profile by naming it in its own folder, without ever holding the
token:

```bash
echo 'TG_PING_PROFILE=cluster' > .tg-ping.env
```

## If a token leaks

Send `/revoke` to BotFather and choose the bot. The old token stops working at
once. Then run `tg-ping init` again with the new one. Because the bot is a
separate account, nothing of yours is exposed in the meantime.
