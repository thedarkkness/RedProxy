[Unit]
Description=RedProxy MTProto (mtg) Service
Documentation=https://github.com/9seconds/mtg
After=network.target nss-lookup.target

[Service]
Type=simple
User=redproxy
Group=redproxy
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/mtg run /opt/redproxy/configs/mtg.toml
Restart=on-failure
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
