package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.ecomm.web.model.delivery.DeliveryProvider;

public interface DeliveryProviderRepository extends JpaRepository<DeliveryProvider, Integer> {
    
}
