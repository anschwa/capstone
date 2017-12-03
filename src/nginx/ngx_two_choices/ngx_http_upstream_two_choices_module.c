
/*
 * Adam Schwartz Fall 2017
 * Add two-choices as a load balancing algorithm to nginx.
 */

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

static ngx_int_t ngx_http_upstream_init_two_choices_peer(ngx_http_request_t *r,
                                                    ngx_http_upstream_srv_conf_t *us);
static ngx_int_t ngx_http_upstream_get_two_choices_peer(
    ngx_peer_connection_t *pc, void *data);
static char *ngx_http_upstream_two_choices(ngx_conf_t *cf, ngx_command_t *cmd,
                                      void *conf);

static ngx_http_upstream_rr_peer_t *ngx_http_upstream_get_rand_peer(
    ngx_peer_connection_t *pc, void *data);


static ngx_command_t  ngx_http_upstream_two_choices_commands[] = {

    { ngx_string("two_choices"),
      NGX_HTTP_UPS_CONF|NGX_CONF_NOARGS,
      ngx_http_upstream_two_choices,
      0,
      0,
      NULL },

    ngx_null_command
};


static ngx_http_module_t  ngx_http_upstream_two_choices_module_ctx = {
    NULL,                                  /* preconfiguration */
    NULL,                                  /* postconfiguration */

    NULL,                                  /* create main configuration */
    NULL,                                  /* init main configuration */

    NULL,                                  /* create server configuration */
    NULL,                                  /* merge server configuration */

    NULL,                                  /* create location configuration */
    NULL                                   /* merge location configuration */
};


ngx_module_t  ngx_http_upstream_two_choices_module = {
    NGX_MODULE_V1,
    &ngx_http_upstream_two_choices_module_ctx, /* module context */
    ngx_http_upstream_two_choices_commands, /* module directives */
    NGX_HTTP_MODULE,                       /* module type */
    NULL,                                  /* init master */
    NULL,                                  /* init module */
    NULL,                                  /* init process */
    NULL,                                  /* init thread */
    NULL,                                  /* exit thread */
    NULL,                                  /* exit process */
    NULL,                                  /* exit master */
    NGX_MODULE_V1_PADDING
};


static ngx_int_t
ngx_http_upstream_init_two_choices(ngx_conf_t *cf,
                              ngx_http_upstream_srv_conf_t *us)
{
    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, cf->log, 0,
                   "init two_choices");

    if (ngx_http_upstream_init_round_robin(cf, us) != NGX_OK) {
        return NGX_ERROR;
    }

    us->peer.init = ngx_http_upstream_init_two_choices_peer;

    return NGX_OK;
}


static ngx_int_t
ngx_http_upstream_init_two_choices_peer(ngx_http_request_t *r,
                                   ngx_http_upstream_srv_conf_t *us)
{
    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "init two_choices peer");

    if (ngx_http_upstream_init_round_robin_peer(r, us) != NGX_OK) {
        return NGX_ERROR;
    }

    r->upstream->peer.get = ngx_http_upstream_get_two_choices_peer;

    return NGX_OK;
}


static ngx_int_t
ngx_http_upstream_get_two_choices_peer(ngx_peer_connection_t *pc, void *data)
{
    ngx_http_upstream_rr_peer_data_t  *rrp = data;

    ngx_http_upstream_rr_peer_t       *peer, *best;
    ngx_http_upstream_rr_peers_t      *peers;

    peers = rrp->peers;

    /* if there's only one peer, no need to load balance */
    if (peers->single || peers->number / 3 == 1) {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                       "get two_choices peer, single rr");
        return ngx_http_upstream_get_round_robin_peer(pc, rrp);
    }

    /* two-choices:
     * first select two random peers, then choose the one with the least load
     */

    ngx_http_upstream_rr_peers_wlock(peers);
    
    /* for simplicity, assume that choice one is best */
    best = ngx_http_upstream_get_rand_peer(pc, rrp);
    peer = ngx_http_upstream_get_rand_peer(pc, rrp);

    if (best == NULL || peer == NULL) {
        ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                       "get two_choices peer, no peer found, %d", peers->number);
        goto failed;
    }

    /* Assign the peer with the least connections to nginx. */
    if (peer->conns * best->weight < best->conns * peer->weight) {
        best = peer;
    }

    pc->sockaddr = best->sockaddr;
    pc->socklen = best->socklen;
    pc->name = &best->name;

    best->conns++;
    rrp->current = best;

    ngx_log_debug2(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "get two-choices peer, peer: %d, best: %d", peer, best);

    ngx_http_upstream_rr_peers_unlock(peers);

    return NGX_OK;

failed:

    ngx_http_upstream_rr_peers_unlock(peers);
    pc->name = peers->name;
    return NGX_BUSY;
}


static char *
ngx_http_upstream_two_choices(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_upstream_srv_conf_t  *uscf;

    uscf = ngx_http_conf_get_module_srv_conf(cf, ngx_http_upstream_module);

    if (uscf->peer.init_upstream) {
        ngx_conf_log_error(NGX_LOG_WARN, cf, 0,
                           "load balancing method redefined");
    }

    uscf->peer.init_upstream = ngx_http_upstream_init_two_choices;

    uscf->flags = NGX_HTTP_UPSTREAM_CREATE
        |NGX_HTTP_UPSTREAM_WEIGHT
        |NGX_HTTP_UPSTREAM_MAX_CONNS
        |NGX_HTTP_UPSTREAM_MAX_FAILS
        |NGX_HTTP_UPSTREAM_FAIL_TIMEOUT
        |NGX_HTTP_UPSTREAM_DOWN
        |NGX_HTTP_UPSTREAM_BACKUP;

    return NGX_CONF_OK;
}

static ngx_http_upstream_rr_peer_t *
ngx_http_upstream_get_rand_peer(ngx_peer_connection_t *pc, void *data)
{
    ngx_http_upstream_rr_peer_data_t  *rrp = data;

    time_t                            now;
    ngx_uint_t                        i, rmin, rmax, rnum, offset;
    ngx_http_upstream_rr_peer_t       *peer, *randp;
    ngx_http_upstream_rr_peers_t      *peers;

    now = ngx_time();
    peers = rrp->peers;
    randp = NULL;

    /*
     * select a random peer. if it is down, try the "next" one. not
     * every index is a valid peer, ex: &peer[0] == foo, &peer[3] == bar,
     * &peer[6] == baz, etc. The magic number here is 3.
     * According to peers->number, there are 3 times too many peers, but I don't know why
     */

    peer = peers->peer;

    rmin = 0;
    rmax = (peers->number / 3) - 1;
    rnum = ngx_random() % (rmax + 1 - rmin) + rmin;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "get random peer, rnum = %d", rnum);

    /* multiply by 3 to get correct indexing */
    offset = rnum * 3;

    for (i = 0; i < rmax * 3; i += 3) {
        randp = &peer[offset + i];

        if (peer->down) {
            continue;
        }

        else if (peer->max_fails
                 && peer->fails >= peer->max_fails
                 && now - peer->checked <= peer->fail_timeout)
        {
            continue;
        }

        else if (peer->max_conns && peer->conns >= peer->max_conns) {
            continue;
        }

        else {
            ngx_log_debug3(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                           "get random peer, rnum = %d, i = %d, peer = %d", rnum, i, offset+i);
            break;
        }
    }

    return randp;
}
