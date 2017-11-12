# compile my module into nginx
                                               
random="/Users/schwa/nginx/ngx_random"
twochoices="/Users/schwa/nginx/ngx_two_choices"

cd "nginx-1.13.6"
make clean

if [ $1 = "off" ]; then
    echo "configure Nginx for production..."
    ./configure --with-compat --add-dynamic-module=$random --add-dynamic-module=$twochoices
else
    echo "configure Nginx with debugging..."
    ./configure --with-debug --with-compat --add-dynamic-module=$random --add-dynamic-module=$twochoices
fi

make && make install
