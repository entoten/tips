
**パフォーマンスチューニングの提案**

ユーザーがパフォーマンスチューニングをしたいと言っていますが、何を最適化したいのかを詳しく理解する必要があります。おそらく、Raspberry Pi 4 の Tailscale エグジットノードのパフォーマンスを向上させたいのだと思います。設定でネットワークスタックの最適化、ハードウェアオフロードの有効化、sysctlの調整、iptables調整、WireGuardの最適化、CPUアフィニティ、不要なサービスの無効化など提案できます。また、mtcpや大きなMTU、DSCPの調整も有効です。

**パフォーマンスチューニングの提案**

Raspberry Pi 4 のパフォーマンスチューニングにはいくつかの方法があります。まず、sysctl パラメータやソケットバッファサイズ、オフロード機能の有効化を検討します。また、ネットワークスタックの最適化や、CPUの割り当て、WireGuardのCPUピニング、nftablesの使用なども有効です。さらに、パフォーマンスモニタリングツールを使用し、経路制御（AQM）やCPU省電力設定の調整も行います。最後に、関連リンクをまとめて提供します。


**パフォーマンスチューニングのリファレンス**

Linuxのチューニングに関して、sysctlの設定などに関する参考として、fasterdata.es.netのサイト（host-tuning/linux）が有益です。また、オフロードの設定に関しては、Red Hatのドキュメントが参考になりますが、GRO/LROの設定に関しては、ネットワークカードによりデフォルトで有効化されていることが多いため、パフォーマンス


**CPUオプティマイゼーションの提案**

Tailscaleの「パフォーマンス最適化のベストプラクティス」では、トランスポートオフロードの有効化が提案されています。また、CPUガバナーに関しては、Pi4でのパフォーマンスに役立つ情報として、cpufreq-utilsに関連する資料が参考になるかもしれません。具体的な文献がない場合、一般的なCPUの最適化は、fasterdataのリソースを活用するのが便利かもしれません。

**パフォーマンスチューニング提案**

パフォーマンス向上のために以下の分野をチューニングできます。

1. **CPU周り**: CPUガバナやIRQ親和性、プロセスピンの設定
2. **ネットワークスタック**: sysctlパラメータやBBRの利用
3. **オフロード設定**: GRO、GSO、LROのチューニング
4. **ファイアウォール**: nftablesとiptablesのパフォーマンス調整
5. **WireGuard/Tailscale**: MTU設定やTransport Offload Engineの調整
6. **モニタリング**: ベンチマークツールやiperf3の使用
7. **不要サービス無効化**: Bluetooth、WiFi、GUIの無効化
8. **AQM**: fq\_codelの設定

最後に、リソースのリンク集も提供します。


思考時間: 22 秒


以下のポイントを参考に、Raspberry Pi Exit Node（Pi 4＋有線）環境でのパフォーマンスチューニングを行ってみてください。

---

## 1. CPU 周りの最適化

1. **CPU ガバナを “performance” に固定**
   CPU 周波数スケーリングを行わず、常に最大クロックで動作させることで、NAT／暗号化処理時のレイテンシを抑えられます。

   ```bash
   sudo apt install cpufrequtils
   echo "GOVERNOR=\"performance\"" | sudo tee /etc/default/cpufrequtils
   sudo systemctl restart cpufrequtils
   ```

   ([Ask Ubuntu][1])

2. **IRQ（割り込み）の CPU 親和性設定**
   ネットワーク割り込みを特定コアに固定し、アプリケーションスレッドと同じコアで処理させるとキャッシュ効率が上がります。

   ```bash
   # 例：eth0 割り込みを CPU0 に割り当て
   echo 1 | sudo tee /proc/irq/$(grep eth0 /proc/interrupts | awk '{print $1}' | sed 's/://')/smp_affinity
   ```

   ([Red Hat Docs][2])

3. **不要サービスの停止**
   Bluetooth や GUI、未使用のデーモン類は停止・無効化し、CPU リソースを Exit Node 処理に集中させます。

   ```bash
   sudo systemctl disable --now bluetooth
   sudo systemctl disable --now avahi-daemon
   ```

---

## 2. ネットワークスタックのチューニング

1. **カーネルパラメータ調整（`/etc/sysctl.d/99-network.conf`）**

   ```conf
   net.core.default_qdisc = fq
   net.ipv4.tcp_congestion_control = bbr
   net.core.rmem_max = 134217728
   net.core.wmem_max = 134217728
   net.ipv4.tcp_rmem = 4096 87380 134217728
   net.ipv4.tcp_wmem = 4096 65536 134217728
   net.core.netdev_max_backlog = 250000
   net.ipv4.tcp_mtu_probing = 1
   ```

   → BBR 有効化で輻輳制御を高速化 ([TechRepublic][3])
   → 大きめのバッファで高スループットを安定させる ([fasterdata.es.net][4])

2. **AQM（Active Queue Management）の適用**
   遅延防止のために `fq_codel`／`cake` を qdisc に設定します。

   ```bash
   sudo tc qdisc replace dev eth0 root fq_codel
   ```

---

## 3. NIC オフロード設定

1. **GRO/LRO/GSO の最適化**
   パケット集約機能のオン・オフを切り替え、スループットの改善を検証します。

   ```bash
   sudo ethtool -K eth0 gro on
   sudo ethtool -K eth0 lro on
   sudo ethtool -K eth0 gso on
   ```

   ([Red Hat Customer Portal][5])

---

## 4. ファイアウォール処理の高速化

* **nftables への移行検討**
  iptables より低レイテンシ／高スループットを実現しやすい場合があります。
* **conntrack テーブルサイズ調整**
  大量のセッションを扱う場合は `nf_conntrack_max` を増やすなど。

---

## 5. WireGuard／Tailscale 固有の調整

1. **MTU 最適化**
   `tailscale up --mtu=<最適MTU>` で VPN パケットの分割を抑え、オーバーヘッドを最小化。
2. **Tailscale Transport Offload**
   ユーザースペース版ではなくカーネル版 WireGuard（`tailscaled`）を使い、ハードウェア暗号化を活用します ([Tailscale][6])。

---

## 6. ベンチマークとモニタリング

* **iperf3**：スループット測定

  ```bash
  iperf3 -s   # サーバ側
  iperf3 -c <Pi4_IP> -R  # クライアント側
  ```
* **htop, iftop, bmon**：CPU・帯域・パケット状況
* **perf, sysstat**：カーネルプロファイリング

---

## 7. 定期的なチューニング見直し

環境や負荷によって最適値は変動します。変更ごとに必ずベンチマークを取り、設定を微調整してください。

---

## リンク集

* Linux Tuning - Fasterdata (ESnet) – カーネル・ネットワークチューニングガイド ([fasterdata.es.net][4])
* Red Hat: Disable/Enable GRO, LRO via ethtool ([Red Hat Customer Portal][5])
* Red Hat: IRQ チューニング（smp\_affinity） ([Red Hat Docs][2])
* WireGuard Performance Tuning – Pro Custodibus ([Pro Custodibus][7])
* Tailscale Performance Best Practices ([Tailscale][6])
* How to enable TCP BBR – TechRepublic ([TechRepublic][3])

[1]: https://askubuntu.com/questions/1021748/set-cpu-governor-to-performance-in-18-04?utm_source=chatgpt.com "Set CPU governor to performance in 18.04 - Ask Ubuntu"
[2]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html/performance_tuning_guide/s-cpu-irq?utm_source=chatgpt.com "4.3. Interrupts and IRQ Tuning | Red Hat Product Documentation"
[3]: https://www.techrepublic.com/article/how-to-enable-tcp-bbr-to-improve-network-speed-on-linux/?utm_source=chatgpt.com "How to enable TCP BBR to improve network speed on Linux"
[4]: https://fasterdata.es.net/host-tuning/linux/?utm_source=chatgpt.com "Linux Tuning - Fasterdata - ESnet"
[5]: https://access.redhat.com/solutions/20278?utm_source=chatgpt.com "NICs with RX acceleration (GRO/LRO/TPA/etc) may suffer from bad ..."
[6]: https://tailscale.com/kb/1320/performance-best-practices?utm_source=chatgpt.com "Performance best practices · Tailscale Docs"
[7]: https://www.procustodibus.com/blog/2022/12/wireguard-performance-tuning/?utm_source=chatgpt.com "WireGuard Performance Tuning - Pro Custodibus"
