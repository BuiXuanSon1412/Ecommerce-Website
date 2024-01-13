package com.ecomm.web.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.product.Discount;
import com.ecomm.web.model.store.Store;

@Repository
public interface DiscountRepository extends JpaRepository<Discount, Integer>{
    //@Query(value = "SELECT d.* FROM product.discount d WHERE is_active = true AND store_id = :storeId")
    //List<Discount> findActiveDiscountsByStore(Integer storeId);
    List<Discount> findByStore(Store store);
}
