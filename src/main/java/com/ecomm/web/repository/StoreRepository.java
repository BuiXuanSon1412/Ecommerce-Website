package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.UserEntity;

@Repository
public interface StoreRepository extends JpaRepository<Store, Integer> {
    Store findByUser(UserEntity user);
}
