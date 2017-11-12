# (re)compile and load my module into nginx

cd "nginx-1.13.6"
make modules
echo "cp modules"
cp objs/ngx_http_upstream_random_module.so /usr/local/nginx/modules/ngx_http_upstream_random_module.so
cp objs/ngx_http_upstream_two_choices_module.so /usr/local/nginx/modules/ngx_http_upstream_two_choices_module.so

echo "restarting nginx..."
nginx -s stop
nginx
echo "done."

echo "nginx is runing with PIDs..."
ps auwx | grep [n]ginx
