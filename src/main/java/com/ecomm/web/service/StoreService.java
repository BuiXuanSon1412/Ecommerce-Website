package com.ecomm.web.service;

import java.util.List;

import com.ecomm.web.dto.delivery.DeliveryProviderDto;
import com.ecomm.web.dto.store.DeliveryMethodDto;
import com.ecomm.web.dto.store.StoreDto;

public interface StoreService {
    public void registerStore(StoreDto storeDto);
    List<DeliveryProviderDto> findAll();
    boolean updateMethod(String methodName, String username);
    List<DeliveryMethodDto> findDeliveryMethodByUsername(String username);
    StoreDto findStoreByUsername(String username);
    void saveStore(StoreDto store);
}
