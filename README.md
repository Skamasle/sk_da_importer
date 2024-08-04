# v-import-directadmin v2
2.0-beta-1.0:
- Improve Output
- Now restore subdomain
- Advice what database user not restored

TODO in V2
- Restore PHP version
- Restore CRON and FIX path
- Restore DNS / MX
- Mail restoring not tested yet

# sk_da_importer v1
Import full user backup from directadmin in to vestacp

This ill import FULL User backup from DirectAdmin to vestacp

- Version 0.2 can:

- Import mysql and mysql user / passwords
- Domains / DOmains files
- Mail accounts and mail passwords

Optional:
 - Modify sk_get_dom set it to 1 if you want scan file for get domain paths, this some time not working, is depends of you DA config, or set to 2 if you just want take it from domains dis and set path as public_html
