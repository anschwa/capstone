# compile my module into nginx
                                               
random="$HOME/Desktop/capstone/src/nginx/ngx_random"
twochoices="$HOME/Desktop/capstone/src/nginx/ngx_two_choices"

cd "$HOME/nginx-1.13.7"
make clean

if [ $1 = "on" ]; then
    echo "configure Nginx for production..."
    ./configure --with-debug --with-compat --add-dynamic-module=$random --add-dynamic-module=$twochoices
else
    echo "configure Nginx with debugging..."
    ./configure --with-compat --add-dynamic-module=$random --add-dynamic-module=$twochoices
fi

make && make install
