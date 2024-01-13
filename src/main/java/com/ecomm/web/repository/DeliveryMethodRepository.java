package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.ecomm.web.model.store.DeliveryMethod;
import com.ecomm.web.model.store.Store;

import java.util.List;


public interface DeliveryMethodRepository extends JpaRepository<DeliveryMethod, Integer> {
    List<DeliveryMethod> findByStore(Store store);
    @Query(value = "SELECT * FROM store.delivery_method WHERE method_name = :methodName AND store_id = :storeId", nativeQuery = true)
    DeliveryMethod findByMethodNameAndStore(String methodName, Integer storeId);
}
