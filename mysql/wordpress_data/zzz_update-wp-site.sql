# This little script will set the WordPress home and siteurl to http://localhost/
select wp_options.option_name, wp_options.option_value from wp_options where wp_options.option_name in ('siteurl','home');
update wp_options set option_value = 'http://localhost/' where option_name in ('siteurl','home');
select wp_options.option_name, wp_options.option_value from wp_options where wp_options.option_name in ('siteurl','home');
