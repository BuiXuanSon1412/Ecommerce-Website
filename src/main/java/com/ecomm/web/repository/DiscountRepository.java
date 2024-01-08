package com.ecomm.web.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.ecomm.web.model.product.Discount;
import com.ecomm.web.model.store.Store;

public interface DiscountRepository extends JpaRepository<Discount, Integer>{
    List<Discount> findByStore(Store store);
}
