-- # This little script will set the WordPress home and siteurl to http://localhost/
select wp_options.option_name, wp_options.option_value from wp_options where wp_options.option_name in ('siteurl','home');
update wp_options set option_value = 'http://localhost/' where option_name in ('siteurl','home');
select wp_options.option_name, wp_options.option_value from wp_options where wp_options.option_name in ('siteurl','home');
/* original: doesn't work.
update wp_postmeta set meta_value='/cgi-bin/classbrowser'
where wp_postmeta.meta_id in (select meta_id
								from wp_postmeta
								where wp_postmeta.post_id in (select wp_posts.ID
																from wp_posts
																where post_type = 'nav_menu_item'
																	and post_title = 'Data Schema')
									and meta_key = '_menu_item_url'
									and meta_value like '%content/schema%');
*/
-- This version works - needed to select * from wp_postmeta as a subquery and alias it.
update wp_postmeta set meta_value='/cgi-bin/classbrowser'
where wp_postmeta.meta_id in
    (select meta_id
    from (select * from wp_postmeta) as subq
    inner join wp_posts on subq.post_id = wp_posts.ID
    where post_type = 'nav_menu_item' and post_title = 'Data Schema')
and meta_key = '_menu_item_url' and meta_value like '%content/schema%';
