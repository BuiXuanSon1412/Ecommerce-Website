package com.ecomm.web.service;

import java.util.List;

import com.ecomm.web.dto.delivery.DeliveryProviderDto;
import com.ecomm.web.dto.store.DeliveryMethodDto;
import com.ecomm.web.dto.store.StoreDto;

public interface StoreService {
    public void registerStore(StoreDto storeDto);
    List<DeliveryProviderDto> findAll();
    void registerDeliveryProvider(Integer dpid);
    List<DeliveryMethodDto> findDeliveryMethodByUsername(String username);
    boolean updateMethod(String methodName, String username);
}
