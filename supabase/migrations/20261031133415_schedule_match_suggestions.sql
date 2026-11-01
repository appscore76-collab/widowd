-- Tops up every listed member's match suggestions once a day at 04:17 UTC.
create extension if not exists pg_cron;

select cron.schedule(
  'suggest-matches-daily',
  '17 4 * * *',
  $$select private.suggest_matches_for_everyone()$$
);
