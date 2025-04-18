# Perplexity Daily News Summary
Daily news summarized by AI and delivered directly to inbox. 

This project contains a systemd service/timer which will execute the operation once a day by default.

The systemd service will call a simple bash script to call the Perplexity API with a prompt and email the result to the user's inbox.
