{ inputs, ... }:
{
  skills.last30days = {
    description = "Research what people actually say about any topic in the last 30 days. Pulls posts and engagement from Reddit, X, YouTube, TikTok, Hacker News, Polymarket, GitHub, and the web.";
    src = "${inputs.last30days-skill}/skills/last30days";
    version = "3.8.1";
  };
}
