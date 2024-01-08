package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.product.Inventory;

@Repository
public interface ProductInventoryRepository extends JpaRepository<Inventory, Integer> {
    
}
