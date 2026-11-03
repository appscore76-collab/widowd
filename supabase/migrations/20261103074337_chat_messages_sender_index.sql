-- Covering index for the messages.sender foreign key (flagged by the
-- performance advisor after the chat migration).
create index if not exists messages_sender_idx on public.messages (sender);
