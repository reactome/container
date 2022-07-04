<?php
class JConfig {
  public $offline = '0';
  public $offline_message = 'This site is down for maintenance.<br />Please check back again soon.';
  public $display_offline_message = '1';
  public $offline_image = '';
  public $sitename = 'Reactome Pathway Database';
  public $editor = 'jce';
  public $captcha = '0';
  public $list_limit = '20';
  public $access = '1';
  public $debug = '0';
  public $debug_lang = '0';
  public $dbtype = 'mysqli';
  public $host = 'mysql-for-joomla';
  public $user = 'root'; # Set this before running the container
  public $password = 'root'; # Set this before running the container
  public $db = 'website';
  public $dbprefix = 'rlp_';
  public $live_site = '';
  public $secret = 'joomla_secret';
  public $gzip = '0';
  public $error_reporting = 'default';
  public $helpurl = 'https://help.joomla.org/proxy?keyref=Help{major}{minor}:{keyref}&lang={langcode}';
  public $ftp_host = '';
  public $ftp_port = '';
  public $ftp_user = '';
  public $ftp_pass = '';
  public $ftp_root = '';
  public $ftp_enable = '0';
  public $offset = 'America/Toronto';
  public $mailonline = '1';
  public $mailer = 'mail';
  public $mailfrom = 'yourmail@yourdomain.com';
  public $fromname = 'Reactome';
  public $sendmail = '/usr/sbin/sendmail';
  public $smtpauth = '0';
  public $smtpuser = '';
  public $smtppass = '';
  public $smtphost = 'localhost';
  public $smtpsecure = 'none';
  public $smtpport = '25';
  public $caching = '0';
  public $cache_handler = 'file';
  public $cachetime = '15';
  public $cache_platformprefix = '0';
  public $MetaDesc = 'Reactome is pathway database which provides intuitive bioinformatics tools for the visualisation, interpretation and analysis of pathway knowledge.';
  public $MetaKeys = 'pathway,reactions,graph,bioinformatics';
  public $MetaTitle = '1';
  public $MetaAuthor = '0';
  public $MetaVersion = '0';
  public $robots = '';
  public $sef = '1';
  public $sef_rewrite = '1';
  public $sef_suffix = '0';
  public $unicodeslugs = '0';
  public $feed_limit = '10';
  public $feed_email = 'none';
  public $log_path = '<XAMPP_HOME>/htdocs/Website/administrator/logs';
  public $tmp_path = '<XAMPP_HOME>/htdocs/Website/tmp';
  public $lifetime = '45';
  public $session_handler = 'database';
  public $memcache_persist = '1';
  public $memcache_compress = '0';
  public $memcache_server_host = 'localhost';
  public $memcache_server_port = '11211';
  public $memcached_persist = '1';
  public $memcached_compress = '0';
  public $memcached_server_host = 'localhost';
  public $memcached_server_port = '11211';
  public $redis_persist = '1';
  public $redis_server_host = 'localhost';
  public $redis_server_port = '6379';
  public $redis_server_auth = '';
  public $redis_server_db = '0';
  public $proxy_enable = '0';
  public $proxy_host = '';
  public $proxy_port = '';
  public $proxy_user = '';
  public $proxy_pass = '';
  public $massmailoff = '0';
  public $MetaRights = '';
  public $sitename_pagetitles = '2';
  public $force_ssl = '0';
  public $session_memcache_server_host = 'localhost';
  public $session_memcache_server_port = '11211';
  public $session_memcached_server_host = 'localhost';
  public $session_memcached_server_port = '11211';
  public $frontediting = '1';
  public $cookie_domain = '';
  public $cookie_path = '';
  public $asset_id = '1';
  public $replyto = '';
  public $replytoname = '';
  public $shared_session = '0';
  public $session_redis_server_host = 'localhost';
  public $session_redis_server_port = '6379';
  public $show_notice_mod = '0';
  public $ga_tracking_code = 'UA-1';
}
