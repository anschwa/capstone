
/*
 * Adam Schwartz Fall 2017
 * Add random as a load balancing algorithm to nginx.
 */


#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

static ngx_int_t ngx_http_upstream_init_random_peer(ngx_http_request_t *r,
                                                    ngx_http_upstream_srv_conf_t *us);
static ngx_int_t ngx_http_upstream_get_random_peer(
    ngx_peer_connection_t *pc, void *data);
static char *ngx_http_upstream_random(ngx_conf_t *cf, ngx_command_t *cmd,
                                      void *conf);
/* static ngx_int_t ngx_http_upstream_get_least_conn_peer( */
/*     ngx_peer_connection_t *pc, void *data); */


typedef struct {
    ngx_int_t npeers;
    ngx_int_t naddrs;
} ngx_http_upstream_random_peer_info_t;

static ngx_http_upstream_random_peer_info_t peer_info = {
    0,
    0
};


static ngx_command_t  ngx_http_upstream_random_commands[] = {

    { ngx_string("random"),
      NGX_HTTP_UPS_CONF|NGX_CONF_NOARGS,
      ngx_http_upstream_random,
      0,
      0,
      NULL },

    ngx_null_command
};


static ngx_http_module_t  ngx_http_upstream_random_module_ctx = {
    NULL,                                  /* preconfiguration */
    NULL,                                  /* postconfiguration */

    NULL,                                  /* create main configuration */
    NULL,                                  /* init main configuration */

    NULL,                                  /* create server configuration */
    NULL,                                  /* merge server configuration */

    NULL,                                  /* create location configuration */
    NULL                                   /* merge location configuration */
};


ngx_module_t  ngx_http_upstream_random_module = {
    NGX_MODULE_V1,
    &ngx_http_upstream_random_module_ctx, /* module context */
    ngx_http_upstream_random_commands, /* module directives */
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
ngx_http_upstream_init_random(ngx_conf_t *cf,
                              ngx_http_upstream_srv_conf_t *us)
{
    ngx_http_upstream_server_t *server;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, cf->log, 0,
                   "init random");

    if (ngx_http_upstream_init_round_robin(cf, us) != NGX_OK) {
        return NGX_ERROR;
    }

    us->peer.init = ngx_http_upstream_init_random_peer;

    /*
     * store important peer information from upstream sever config
     * each peer may have N other peers associated with it, so to get
     * the total number of peers we also need the number of addresses
     * associated with each peer.
     */

    server = us->servers->elts;
    peer_info.npeers = us->servers->nelts;
    peer_info.naddrs = server[0].naddrs;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, cf->log, 0,
                   "num peers = %d", peer_info.npeers);

    ngx_log_debug2(NGX_LOG_DEBUG_HTTP, cf->log, 0,
                   "num addrs = %d", 0, server[0].naddrs);

    return NGX_OK;
}


static ngx_int_t
ngx_http_upstream_init_random_peer(ngx_http_request_t *r,
                                   ngx_http_upstream_srv_conf_t *us)
{
    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "init random peer");

    if (ngx_http_upstream_init_round_robin_peer(r, us) != NGX_OK) {
        return NGX_ERROR;
    }

    r->upstream->peer.get = ngx_http_upstream_get_random_peer;

    return NGX_OK;
}


static ngx_int_t
ngx_http_upstream_get_random_peer(ngx_peer_connection_t *pc, void *data)
{
    ngx_http_upstream_rr_peer_data_t  *rrp = data;

    // time_t                         now;
    // uintptr_t                      m;
    // ngx_int_t                      rc, total;
    // ngx_uint_t                     i, n, p, many;
    // ngx_http_upstream_rr_peer_t   *peer, *best, *random;
    time_t                         now;
    uintptr_t                      m;
    ngx_uint_t                     i, n, p, rmin, rmax, rnum, offset;
    ngx_http_upstream_rr_peer_t    *peer, *randp;
    ngx_http_upstream_rr_peers_t   *peers;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "get random peer, try: %ui", pc->tries);

    if (rrp->peers->single) {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                       "get random peer, single rr");
        return ngx_http_upstream_get_round_robin_peer(pc, rrp);
    }

    now = ngx_time();
    peers = rrp->peers;
    randp = NULL;
    p = 0;

    ngx_http_upstream_rr_peers_wlock(peers);

    /*
     * select a random peer. if it is down, try the "next" one.
     * not every index is a valid peer, ex: &peer[0] == foo,
     * &peer[3] == bar, &peer[6] == baz, etc.
     */

    peer = peers->peer;

    rmin = 0;
    rmax = peer_info.npeers - 1;
    rnum = ngx_random() % (rmax + 1 - rmin) + rmin;

    /* multiply by 3 to get correct indexing */
    offset = rnum * 3;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "get random peer, rnum = %d", rnum);

    for (i = 0; i < rmax * 3; i += 3) {
        randp = &peer[offset + i];

        n = i / (8 * sizeof(uintptr_t));
        m = (uintptr_t) 1 << i % (8 * sizeof(uintptr_t));

        if (rrp->tried[n] & m) {
            continue;
        }

        else if (peer->down) {
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
                           "rnum = %d, i = %d, peer = %d", rnum, i, offset+i);
            break;
        }
    }


    if (randp == NULL) {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                       "get random peer, no peer found");
        goto failed;
    }

    /* assign peer to nginx */
    pc->sockaddr = randp->sockaddr;
    pc->socklen = randp->socklen;
    pc->name = &randp->name;

    randp->conns++;
    rrp->current = randp;

    n = p / (8 * sizeof(uintptr_t));
    m = (uintptr_t) 1 << p % (8 * sizeof(uintptr_t));

    rrp->tried[n] |= m;

    ngx_http_upstream_rr_peers_unlock(peers);

    return NGX_OK;

    /* two-choices: return ngx_http_upstream_get_least_conn_peer(pc, rrp); */

failed:

    ngx_http_upstream_rr_peers_unlock(peers);
    pc->name = peers->name;
    return NGX_BUSY;
}


static char *
ngx_http_upstream_random(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_upstream_srv_conf_t  *uscf;

    uscf = ngx_http_conf_get_module_srv_conf(cf, ngx_http_upstream_module);

    if (uscf->peer.init_upstream) {
        ngx_conf_log_error(NGX_LOG_WARN, cf, 0,
                           "load balancing method redefined");
    }

    uscf->peer.init_upstream = ngx_http_upstream_init_random;

    uscf->flags = NGX_HTTP_UPSTREAM_CREATE
        |NGX_HTTP_UPSTREAM_WEIGHT
        |NGX_HTTP_UPSTREAM_MAX_CONNS
        |NGX_HTTP_UPSTREAM_MAX_FAILS
        |NGX_HTTP_UPSTREAM_FAIL_TIMEOUT
        |NGX_HTTP_UPSTREAM_DOWN
        |NGX_HTTP_UPSTREAM_BACKUP;

    return NGX_CONF_OK;
}

/* static ngx_int_t */
/* ngx_http_upstream_get_least_conn_peer(ngx_peer_connection_t *pc, void *data) */
/* { */
/*     ngx_http_upstream_rr_peer_data_t  *rrp = data; */

/*     time_t                         now; */
/*     uintptr_t                      m; */
/*     ngx_int_t                      rc, total; */
/*     ngx_uint_t                     i, n, p, many; */
/*     ngx_http_upstream_rr_peer_t   *peer, *best; */
/*     ngx_http_upstream_rr_peers_t  *peers; */

/*     ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0, */
/*                    "get least conn peer, try: %ui", pc->tries); */

/*     if (rrp->peers->single) { */
/*         return ngx_http_upstream_get_round_robin_peer(pc, rrp); */
/*     } */

/*     pc->cached = 0; */
/*     pc->connection = NULL; */

/*     now = ngx_time(); */

/*     peers = rrp->peers; */

/*     ngx_http_upstream_rr_peers_wlock(peers); */

/*     best = NULL; */
/*     total = 0; */

/* #if (NGX_SUPPRESS_WARN) */
/*     many = 0; */
/*     p = 0; */
/* #endif */

/*     for (peer = peers->peer, i = 0; */
/*          peer; */
/*          peer = peer->next, i++) */
/*     { */
/*         n = i / (8 * sizeof(uintptr_t)); */
/*         m = (uintptr_t) 1 << i % (8 * sizeof(uintptr_t)); */

/*         if (rrp->tried[n] & m) { */
/*             continue; */
/*         } */

/*         if (peer->down) { */
/*             continue; */
/*         } */

/*         if (peer->max_fails */
/*             && peer->fails >= peer->max_fails */
/*             && now - peer->checked <= peer->fail_timeout) */
/*         { */
/*             continue; */
/*         } */

/*         if (peer->max_conns && peer->conns >= peer->max_conns) { */
/*             continue; */
/*         } */

/*         /\* */
/*          * select peer with least number of connections; if there are */
/*          * multiple peers with the same number of connections, select */
/*          * based on round-robin */
/*          *\/ */

/*         if (best == NULL */
/*             || peer->conns * best->weight < best->conns * peer->weight) */
/*         { */
/*             best = peer; */
/*             many = 0; */
/*             p = i; */

/*         } else if (peer->conns * best->weight == best->conns * peer->weight) { */
/*             many = 1; */
/*         } */
/*     } */

/*     if (best == NULL) { */
/*         ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0, */
/*                        "get least conn peer, no peer found"); */

/*         goto failed; */
/*     } */

/*     if (many) { */
/*         ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0, */
/*                        "get least conn peer, many"); */

/*         for (peer = best, i = p; */
/*              peer; */
/*              peer = peer->next, i++) */
/*         { */
/*             n = i / (8 * sizeof(uintptr_t)); */
/*             m = (uintptr_t) 1 << i % (8 * sizeof(uintptr_t)); */

/*             if (rrp->tried[n] & m) { */
/*                 continue; */
/*             } */

/*             if (peer->down) { */
/*                 continue; */
/*             } */

/*             if (peer->conns * best->weight != best->conns * peer->weight) { */
/*                 continue; */
/*             } */

/*             if (peer->max_fails */
/*                 && peer->fails >= peer->max_fails */
/*                 && now - peer->checked <= peer->fail_timeout) */
/*             { */
/*                 continue; */
/*             } */

/*             if (peer->max_conns && peer->conns >= peer->max_conns) { */
/*                 continue; */
/*             } */

/*             peer->current_weight += peer->effective_weight; */
/*             total += peer->effective_weight; */

/*             if (peer->effective_weight < peer->weight) { */
/*                 peer->effective_weight++; */
/*             } */

/*             if (peer->current_weight > best->current_weight) { */
/*                 best = peer; */
/*                 p = i; */
/*             } */
/*         } */
/*     } */

/*     best->current_weight -= total; */

/*     if (now - best->checked > best->fail_timeout) { */
/*         best->checked = now; */
/*     } */

/*     pc->sockaddr = best->sockaddr; */
/*     pc->socklen = best->socklen; */
/*     pc->name = &best->name; */

/*     best->conns++; */

/*     rrp->current = best; */

/*     n = p / (8 * sizeof(uintptr_t)); */
/*     m = (uintptr_t) 1 << p % (8 * sizeof(uintptr_t)); */

/*     rrp->tried[n] |= m; */

/*     ngx_http_upstream_rr_peers_unlock(peers); */

/*     return NGX_OK; */

/* failed: */

/*     if (peers->next) { */
/*         ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0, */
/*                        "get least conn peer, backup servers"); */

/*         rrp->peers = peers->next; */

/*         n = (rrp->peers->number + (8 * sizeof(uintptr_t) - 1)) */
/*             / (8 * sizeof(uintptr_t)); */

/*         for (i = 0; i < n; i++) { */
/*             rrp->tried[i] = 0; */
/*         } */

/*         ngx_http_upstream_rr_peers_unlock(peers); */

/*         rc = ngx_http_upstream_get_least_conn_peer(pc, rrp); */

/*         if (rc != NGX_BUSY) { */
/*             return rc; */
/*         } */

/*         ngx_http_upstream_rr_peers_wlock(peers); */
/*     } */

/*     ngx_http_upstream_rr_peers_unlock(peers); */

/*     pc->name = peers->name; */

/*     return NGX_BUSY; */
/* } */
