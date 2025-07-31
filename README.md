# Perplexity Daily News Summary
Daily news summarized by AI and delivered directly to inbox. 

# Implementation Details
This project contains a systemd service/timer which will execute the operation once a day by default.

The systemd service will call a simple bash script to call the Perplexity API with a prompt and email the result to the user's inbox using Sendgrid.

# Required secrets
- Perplexity API token
- SendGrid API token

# File permissions example
```
chmod 700 ~/src/perplexity-daily-news-summary
chmod 600 ~/src/perplexity-daily-news-summary/.env
chmod +x ~/src/perplexity-daily-news-summary/perplexity_tech_news.sh
```
