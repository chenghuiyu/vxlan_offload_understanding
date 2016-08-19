
### 网卡NIC的VXLAN offload技术研究报告

----------------------








 **本报告主要介绍了有关网卡NIC的VXLAN的offload技术，先从VXLAN offload产生背景入手，逐一介绍了有关offload的多种技术，并阐述了NIC的VXLAN offload所带来的性能提升。接着结合neutron，介绍了网卡VXLAN offload技术的运行机制，分为Linux bridge+VXLAN offload和OVS+VXLAN offload两种不同的场景，并对其中的网络数据包的封装和解封过程进行了详细的描述。最后，介绍了VXLAN offload技术性能测试方案，由于现阶段的硬件设备并不满足，网卡不支持VXLAN offload技术，所以无法进行对比测试分析，后续如果硬件条件允许，那么可以按照该方案进行测试和对比验证。**


