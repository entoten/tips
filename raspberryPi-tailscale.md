Raspberry Pi 上で Exit Node（サブネット・ルーティング）を動かすには、Kernel の IP フォワーディングを有効にし、NAT（マスカレード）を設定する必要があります。以下の手順で設定を行ってください。

---

## 1. IP フォワーディングを有効化

1. **`/etc/sysctl.d/30-ipforward.conf` を作成して、IPv4／IPv6 フォワーディングを有効にします。**

   ```bash
   sudo tee /etc/sysctl.d/30-ipforward.conf << 'EOF'
   net.ipv4.ip_forward=1
   net.ipv6.conf.all.forwarding=1
   EOF
````

2. **設定を反映します。**

   ```bash
   sudo sysctl --system
   ```

3. **本当に有効になっているか確認します。**

   ```bash
   sysctl net.ipv4.ip_forward
   # → net.ipv4.ip_forward = 1
   sysctl net.ipv6.conf.all.forwarding
   # → net.ipv6.conf.all.forwarding = 1
   ```



## 2. NAT（マスカレード）設定

Exit Node 経由で送られてきたパケットを、Pi の外向きインターフェイス（ここでは `eth0` や `wlan0`）から送出できるよう、iptables でマスカレードします。

```bash
# eth0 を外向きインターフェイスとする例
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# フォワードを許可
sudo iptables -A FORWARD -i tailscale0 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o tailscale0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

> **ポイント**
>
> * `eth0` の部分は実家の回線に繋がるインターフェイス名（`eth0`／`wlan0` 等）に合わせてください。
> * iptables の設定を再起動後も保持したい場合は、`iptables-save`／`iptables-restore` か、`netfilter-persistent` パッケージを利用してください。

---

## 3. Tailscale Exit Node を再度起動

設定が終わったら、改めて Exit Node を広告します。

```bash
sudo tailscale up --advertise-exit-node
```

警告が出ずに正常に Exit Node が有効化されるはずです。

---

## リンク集

* **Tailscale: IP フォワーディングの有効化方法**
  [https://tailscale.com/s/ip-forwarding](https://tailscale.com/s/ip-forwarding)

* **Debian sysctl 永続化設定 (`/etc/sysctl.d`) について**
  [https://www.debian.org/doc/manuals/debian-faq/ch-configuration.ja.html#ssysctl-conf](https://www.debian.org/doc/manuals/debian-faq/ch-configuration.ja.html#ssysctl-conf)

* **iptables マスカレード設定ガイド**
  [https://www.netfilter.org/documentation/HOWTO//nat-HOWTO.html#ss3.1](https://www.netfilter.org/documentation/HOWTO//nat-HOWTO.html#ss3.1)

```
```
